@IsTest
private class UJJAYINIHeaderControllerTest {

    @IsTest
    static void internalUserGetsNameAndEmptyCart() {

        UJJAYINIHeaderController.HeaderInfo info =
            UJJAYINIHeaderController.getHeaderInfo();

        System.assertEquals(0, info.cartCount);
        System.assertNotEquals(null, info.lastName);
    }
}