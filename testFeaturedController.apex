List<UJJAYINIFeaturedWatchesController.FeaturedWatch> watches =
    UJJAYINIFeaturedWatchesController.getFeaturedWatches();

System.debug('FEATURED WATCH COUNT = ' + watches.size());

for (UJJAYINIFeaturedWatchesController.FeaturedWatch w : watches) {
    System.debug(
        'WATCH = ' +
        w.name +
        ' | MODEL = ' +
        w.modelNumber +
        ' | IMAGE = ' +
        w.imageUrl
    );
}
