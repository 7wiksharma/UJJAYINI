AssetFulfillmentService.FulfillmentResult result = AssetFulfillmentService.createAssetsForOrder('801bm00003HCTNuAAP');

System.debug('STATUS=' + result.status);
System.debug('MESSAGE=' + result.message);
System.debug('ASSETS=' + result.assetIds);