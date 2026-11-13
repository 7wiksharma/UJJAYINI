public with sharing class ReservationExpiryScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        ReservationExpiryService.expirePendingReservations();
    }
}