public with sharing class AssetFulfillmentService {

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

        Order orderRecord = [
            SELECT Id,
                   AccountId,
                   Status,
                   EffectiveDate
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orderRecord.Status != 'Activated') {
            throw new IllegalArgumentException(
                'Assets can only be created for an Activated Order.'
            );
        }

        List<OrderItem> orderItems = [
            SELECT Id,
                   OrderId,
                   Product2Id,
                   Quantity,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :orderRecord.Id
        ];

        if (orderItems.isEmpty()) {
            throw new IllegalArgumentException(
                'Order must contain at least one Order Item.'
            );
        }

        String fulfillmentMarker =
            'UJJAYINI-' + String.valueOf(orderRecord.Id);

        List<Asset> existingAssets = [
            SELECT Id
            FROM Asset
            WHERE SerialNumber = :fulfillmentMarker
        ];

        if (!existingAssets.isEmpty()) {

            FulfillmentResult existingResult =
                new FulfillmentResult();

            existingResult.orderId = orderRecord.Id;
            existingResult.status = 'ALREADY_FULFILLED';
            existingResult.message =
                'Assets already exist for this Order.';

            for (Asset existingAsset : existingAssets) {
                existingResult.assetIds.add(existingAsset.Id);
            }

            return existingResult;
        }

        List<Asset> assetsToCreate = new List<Asset>();

        for (OrderItem item : orderItems) {

            if (item.Product2Id == null) {
                throw new IllegalArgumentException(
                    'Order Item is missing Product.'
                );
            }

            if (item.Quantity == null ||
                item.Quantity <= 0) {

                throw new IllegalArgumentException(
                    'Order Item quantity must be greater than zero.'
                );
            }

            Asset asset = new Asset();
            asset.Name = 'UJJAYINI Asset - ' + String.valueOf(item.Id);
            asset.AccountId = orderRecord.AccountId;
            asset.Product2Id = item.Product2Id;
            asset.Quantity = item.Quantity;
            asset.Price = item.TotalPrice;
            asset.PurchaseDate = orderRecord.EffectiveDate;
            asset.Status = 'Purchased';
            asset.SerialNumber = fulfillmentMarker;
            asset.Description =
                'UJJAYINI Order ' +
                String.valueOf(orderRecord.Id);

            assetsToCreate.add(asset);
        }

        insert assetsToCreate;

        FulfillmentResult result =
            new FulfillmentResult();

        result.orderId = orderRecord.Id;
        result.status = 'FULFILLED';
        result.message =
            'Assets created successfully for the Order.';

        for (Asset asset : assetsToCreate) {
            result.assetIds.add(asset.Id);
        }

        return result;
    }
}