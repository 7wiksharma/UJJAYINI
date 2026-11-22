@IsTest
private class UJJAYINIWishlistSpecsControllerTest {

    @IsTest
    static void returnsSpecsForActiveProducts() {

        Product2 watch = new Product2(
            Name = 'Spec Test Watch',
            ProductCode = 'SPEC-TEST-01',
            IsActive = true
        );
        insert watch;

        Test.startTest();
        List<UJJAYINIWishlistSpecsController.Spec> specs =
            UJJAYINIWishlistSpecsController.getSpecs(new List<Id>{ watch.Id });
        Test.stopTest();

        System.assertEquals(1, specs.size());
        System.assertEquals('SPEC-TEST-01', specs[0].productCode);
    }

    @IsTest
    static void ignoresInactiveAndEmptyInput() {

        Product2 retired = new Product2(Name = 'Retired Watch', IsActive = false);
        insert retired;

        System.assertEquals(0, UJJAYINIWishlistSpecsController.getSpecs(new List<Id>{ retired.Id }).size());
        System.assertEquals(0, UJJAYINIWishlistSpecsController.getSpecs(new List<Id>()).size());
        System.assertEquals(0, UJJAYINIWishlistSpecsController.getSpecs(null).size());
    }

    @IsTest
    static void formatsLabels() {

        System.assertEquals('Limited · 4 pieces', UJJAYINIWishlistSpecsController.editionLabel(true, 4));
        System.assertEquals('Limited · 1 piece', UJJAYINIWishlistSpecsController.editionLabel(true, 1));
        System.assertEquals('Limited edition', UJJAYINIWishlistSpecsController.editionLabel(true, null));
        System.assertEquals('Regular production', UJJAYINIWishlistSpecsController.editionLabel(false, 4));
        System.assertEquals('24 months', UJJAYINIWishlistSpecsController.warrantyLabel(24));
        System.assertEquals(null, UJJAYINIWishlistSpecsController.warrantyLabel(null));
        System.assertEquals(null, UJJAYINIWishlistSpecsController.text('   '));
    }
}