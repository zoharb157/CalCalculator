# StoreKit Debugging

## Issue
SDK is stuck at "⬇️ sending reply, getProducts" - JavaScript receives response but doesn't process it.

## Possible Causes

1. **StoreKit Testing Not Enabled**
   - In Xcode: Product > Scheme > Edit Scheme
   - Go to "Run" > "Options" tab
   - Set "StoreKit Configuration" to `StoreKitConfig.storekit`

2. **Product ID Mismatch**
   - Server expects: `calCalculator.weekly.premium` ✅ (matches StoreKitConfig)
   - But SDK might not be finding it in StoreKit

3. **Empty Products Array**
   - SDK returns empty array
   - JavaScript tries to access `product.programs[0]` → crashes
   - Need error handling in server's JavaScript

## Server JavaScript Fix Needed

The server's `GetProducts()` function needs better error handling:

```javascript
const GetProducts = () => {
  callActionAsync({
    action: "getProducts",
    properties: { productIdList: [SUBSCRIPTION_PLAN] },
  }).then((product) => {
    // ✅ ADD THIS CHECK:
    if (!product || !product.programs || product.programs.length === 0) {
      console.error("No products received");
      sendPostRequest("catchError_GetProducts", '', false, "No products found");
      return;
    }
    
    let price = product.programs[0].attributes.offers[0].priceFormatted;
    // ... rest of code
  }).catch((error) => {
    sendPostRequest("catchError_GetProducts", '', false, JSON.stringify(error));
  });
};
```

## Xcode Configuration Check

1. Open Xcode
2. Product > Scheme > Edit Scheme (or Cmd+<)
3. Select "Run" in left sidebar
4. Go to "Options" tab
5. Under "StoreKit Configuration", select `StoreKitConfig.storekit`
6. Click "Close"
7. Clean build folder (Shift+Cmd+K)
8. Rebuild and run

## Testing

After enabling StoreKit testing, the SDK should be able to find products from `StoreKitConfig.storekit` and return them to JavaScript.

