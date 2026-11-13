public without sharing class AssetFulfillmentService {

    public class FulfillmentResult {
        public Id orderId;
        public List<Id> assetIds = new List<Id>();
        public String status;
        public String message;
    }

    public static FulfillmentResult createAssetsForOrder(Id orderId) {

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        /*
         * Retrieve Order information through OrderItem.
         * This avoids relying on a standalone Order query
         * in the external webhook execution context.
         */
        List<OrderItem> orderItems = [
            SELECT Id,
                   OrderId,
                   Product2Id,
                   Quantity,
                   UnitPrice,
                   TotalPrice,
                   Order.AccountId,
                   Order.Status,
                   Order.EffectiveDate
            FROM OrderItem
            WHERE OrderId = :orderId
            WITH SYSTEM_MODE
        ];

        if (orderItems.isEmpty()) {
            throw new IllegalArgumentException(
                'Order must contain at least one Order Item.'
            );
        }

        OrderItem firstItem = orderItems[0];

        if (firstItem.Order.Status != 'Activated') {
            throw new IllegalArgumentException(
                'Assets can only be created for an Activated Order.'
            );
        }

        String fulfillmentMarker =
            'UJJAYINI-' + String.valueOf(orderId);

        /*
         * Check whether Assets already exist.
         * This makes fulfillment idempotent.
         */
        List<Asset> existingAssets = [
            SELECT Id
            FROM Asset
            WHERE SerialNumber = :fulfillmentMarker
            WITH SYSTEM_MODE
        ];

        if (!existingAssets.isEmpty()) {

            FulfillmentResult existingResult =
                new FulfillmentResult();

            existingResult.orderId = orderId;
            existingResult.status = 'ALREADY_FULFILLED';
            existingResult.message =
                'Assets already exist for this Order.';

            for (Asset existingAsset : existingAssets) {
                existingResult.assetIds.add(
                    existingAsset.Id
                );
            }

            return existingResult;
        }

        List<Asset> assetsToCreate =
            new List<Asset>();

        for (OrderItem item : orderItems) {

            if (item.Product2Id == null) {
                throw new IllegalArgumentException(
                    'Order Item is missing Product.'
                );
            }

            if (
                item.Quantity == null ||
                item.Quantity <= 0
            ) {
                throw new IllegalArgumentException(
                    'Order Item quantity must be greater than zero.'
                );
            }

            Asset asset = new Asset();

            asset.Name =
                'UJJAYINI Asset - ' +
                String.valueOf(item.Id);

            asset.AccountId =
                item.Order.AccountId;

            asset.Product2Id =
                item.Product2Id;

            asset.Quantity =
                item.Quantity;

            asset.Price =
                item.TotalPrice;

            asset.PurchaseDate =
                item.Order.EffectiveDate;

            asset.Status =
                'Purchased';

            asset.SerialNumber =
                fulfillmentMarker;

            asset.Description =
                'UJJAYINI Order ' +
                String.valueOf(orderId);

            assetsToCreate.add(asset);
        }

        Database.insert(
            assetsToCreate,
            AccessLevel.SYSTEM_MODE
        );

        FulfillmentResult result =
            new FulfillmentResult();

        result.orderId = orderId;
        result.status = 'FULFILLED';
        result.message =
            'Assets created successfully for the Order.';

        for (Asset asset : assetsToCreate) {
            result.assetIds.add(
                asset.Id
            );
        }

        return result;
    }
}