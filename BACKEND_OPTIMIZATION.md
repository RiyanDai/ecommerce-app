# Backend Optimization - Fix Slow Payment Status Check

## 🔴 MASALAH

Backend `checkPaymentStatus` **terlalu lambat** (10-30 detik) karena harus search timestamp dengan loop:

```php
// Current code loops through timestamps every 5 seconds
for ($timestamp = $startTime; $timestamp >= $tenMinutesAgo; $timestamp -= 5) {
    $testOrderId = $order->order_number . '-' . $timestamp;
    $status = Transaction::status($testOrderId); // API call setiap loop!
}
```

**Masalah:**
- ❌ Bisa butuh 120+ API calls ke Midtrans
- ❌ Setiap call butuh ~200-500ms
- ❌ Total waktu: 10-30 detik
- ❌ Flutter timeout sebelum selesai (3 detik)

---

## ✅ SOLUSI: Simpan Midtrans Order ID di Database

### 1. Create Migration

```bash
php artisan make:migration add_midtrans_order_id_to_orders_table
```

**File:** `database/migrations/xxxx_add_midtrans_order_id_to_orders_table.php`

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('midtrans_order_id')->nullable()->after('order_number');
            $table->index('midtrans_order_id'); // Add index for fast lookup
        });
    }

    public function down()
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['midtrans_order_id']);
            $table->dropColumn('midtrans_order_id');
        });
    }
};
```

```bash
php artisan migrate
```

---

### 2. Update `generateSnapToken` Method

**File:** `app/Http/Controllers/MidtransController.php`

**GANTI bagian ini (sekitar line 70-80):**

```php
// OLD CODE:
$timestamp = time();
$uniqueOrderId = $order->order_number . '-' . $timestamp;

// Store the order_id used for Midtrans in order metadata
$order->updated_at = now();
$order->save();
```

**DENGAN:**

```php
// Generate unique order_id with timestamp
$timestamp = time();
$uniqueOrderId = $order->order_number . '-' . $timestamp;

// ✅ SAVE midtrans_order_id to database for fast lookup later
$order->midtrans_order_id = $uniqueOrderId;
$order->save();

Log::info('Midtrans: Saved order_id to database', [
    'order_number' => $order->order_number,
    'midtrans_order_id' => $uniqueOrderId,
]);
```

---

### 3. Update `checkPaymentStatus` Method

**GANTI seluruh Strategy 1 & 2 (sekitar line 420-520) dengan code yang lebih simple:**

```php
public function checkPaymentStatus(Request $request)
{
    $request->validate([
        'order_number' => 'required|string|exists:orders,order_number',
    ]);

    try {
        // Load order
        $order = Order::where('order_number', $request->order_number)
            ->where('user_id', auth()->id())
            ->firstOrFail();

        $status = null;
        $orderIdUsed = null;
        
        // ✅ FAST PATH: Use saved midtrans_order_id from database
        if ($order->midtrans_order_id) {
            try {
                Log::info('Midtrans: Checking status with saved order_id', [
                    'midtrans_order_id' => $order->midtrans_order_id,
                ]);
                
                $status = Transaction::status($order->midtrans_order_id);
                $orderIdUsed = $order->midtrans_order_id;
                
                Log::info('Midtrans: ✅ Status retrieved successfully', [
                    'midtrans_order_id' => $order->midtrans_order_id,
                    'transaction_status' => $status->transaction_status ?? 'unknown',
                ]);
            } catch (\Exception $e) {
                Log::warning('Midtrans: Saved order_id not found, trying fallback', [
                    'midtrans_order_id' => $order->midtrans_order_id,
                    'error' => $e->getMessage(),
                ]);
            }
        }
        
        // FALLBACK: Try with order_number directly (for old orders without midtrans_order_id)
        if (!$status) {
            try {
                $status = Transaction::status($order->order_number);
                $orderIdUsed = $order->order_number;
                
                Log::info('Midtrans: Status retrieved with order_number', [
                    'order_number' => $order->order_number,
                ]);
            } catch (\Exception $e) {
                Log::warning('Midtrans: Transaction not found', [
                    'order_number' => $order->order_number,
                    'error' => $e->getMessage(),
                ]);
                
                // Return current status from database
                return response()->json([
                    'success' => true,
                    'payment_status' => $order->payment_status,
                    'order_status' => $order->order_status,
                    'transaction_status' => null,
                    'status_updated' => false,
                    'message' => 'Transaction not found in Midtrans. Using database status.',
                    'note' => 'Payment may still be processing. Check again in a few moments.',
                ]);
            }
        }

        if (!$status) {
            return response()->json([
                'success' => true,
                'payment_status' => $order->payment_status,
                'order_status' => $order->order_status,
                'transaction_status' => null,
                'status_updated' => false,
                'message' => 'Transaction not found in Midtrans',
            ]);
        }

        // Extract transaction status
        $transactionStatus = $status->transaction_status ?? null;
        $fraudStatus = $status->fraud_status ?? null;

        // Map Midtrans status to payment_status
        $newPaymentStatus = null;

        switch ($transactionStatus) {
            case 'settlement':
                $newPaymentStatus = 'paid';
                break;
                
            case 'capture':
                if ($fraudStatus === 'challenge') {
                    $newPaymentStatus = 'pending';
                } elseif ($fraudStatus === 'accept') {
                    $newPaymentStatus = 'paid';
                } else {
                    $newPaymentStatus = 'pending';
                }
                break;

            case 'pending':
                $newPaymentStatus = 'pending';
                break;

            case 'expire':
                $newPaymentStatus = 'expired';
                break;

            case 'cancel':
            case 'deny':
                $newPaymentStatus = 'failed';
                break;

            default:
                $newPaymentStatus = $order->payment_status;
                break;
        }

        // Update payment_status if changed
        $statusUpdated = false;
        if ($newPaymentStatus && $order->payment_status !== $newPaymentStatus) {
            $oldPaymentStatus = $order->payment_status;
            $order->payment_status = $newPaymentStatus;
            $order->save();
            $statusUpdated = true;

            Log::info('Midtrans: ✅ Payment status updated', [
                'order_number' => $order->order_number,
                'old_status' => $oldPaymentStatus,
                'new_status' => $newPaymentStatus,
                'transaction_status' => $transactionStatus,
            ]);
        }

        return response()->json([
            'success' => true,
            'payment_status' => $order->payment_status,
            'order_status' => $order->order_status,
            'transaction_status' => $transactionStatus,
            'status_updated' => $statusUpdated,
            'message' => $statusUpdated 
                ? 'Payment status updated successfully' 
                : 'Payment status is up to date',
        ]);

    } catch (\Exception $e) {
        Log::error('Midtrans Check Payment Status Error', [
            'order_number' => $request->order_number ?? 'unknown',
            'error' => $e->getMessage(),
            'trace' => $e->getTraceAsString(),
        ]);

        return response()->json([
            'success' => false,
            'message' => 'Failed to check payment status: ' . $e->getMessage(),
        ], 500);
    }
}
```

---

## 📊 PERBANDINGAN PERFORMA

### Before (Current):
```
Request → Loop 120 timestamps → 120 API calls → 10-30 seconds ❌
```

### After (Optimized):
```
Request → 1 API call with saved order_id → 200-500ms ✅
```

**Speed improvement: 20-60x faster!** 🚀

---

## 🧪 TESTING

### 1. Run Migration
```bash
php artisan migrate
```

### 2. Test New Order
1. Create new order di Flutter
2. Generate payment token
3. Check database: `midtrans_order_id` should be filled
4. Pay via Midtrans
5. Check status - should be **instant** (< 1 second)

### 3. Verify Logs
```bash
tail -f storage/logs/laravel.log | grep "Midtrans:"
```

Should see:
```
Midtrans: Saved order_id to database
Midtrans: Checking status with saved order_id
Midtrans: ✅ Status retrieved successfully
Midtrans: ✅ Payment status updated
```

---

## 🎯 HASIL AKHIR

| Aspect | Before | After |
|--------|--------|-------|
| **Response Time** | 10-30 seconds | 0.2-0.5 seconds |
| **API Calls** | 120+ | 1 |
| **Flutter Timeout** | Yes ❌ | No ✅ |
| **Status Update** | Fails ❌ | Success ✅ |

---

## 📝 SUMMARY

1. ✅ Add `midtrans_order_id` column to `orders` table
2. ✅ Save order_id when generating snap token
3. ✅ Use saved order_id for instant status check
4. ✅ Remove slow timestamp loop
5. ✅ 20-60x faster response time

**Setelah optimization ini, payment status akan update dengan cepat dan Flutter app akan work perfectly!** 🎉
