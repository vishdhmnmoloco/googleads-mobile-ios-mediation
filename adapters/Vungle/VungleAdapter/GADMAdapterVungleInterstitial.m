#import "GADMAdapterVungleInterstitial.h"
#import <GoogleMobileAds/Mediation/GADMAdNetworkConnectorProtocol.h>
#import "vungleHelper.h"

@interface GADMAdapterVungleInterstitial ()<VungleDelegate>
@property(nonatomic, weak) id<GADMAdNetworkConnector> connector;
@end

@implementation GADMAdapterVungleInterstitial

+ (NSString *)adapterVersion {
  return [vungleHelper adapterVersion];
}

+ (Class<GADAdNetworkExtras>)networkExtrasClass {
  return [VungleAdNetworkExtras class];
}

- (instancetype)initWithGADMAdNetworkConnector:(id<GADMAdNetworkConnector>)connector {
  self = [super init];
  if (self) {
    self.connector = connector;
    [[vungleHelper sharedInstance] addDelegate:self];
  }
  return self;
}

- (void)dealloc {
  [self stopBeingDelegate];
}

- (void)getBannerWithSize:(GADAdSize)adSize {
  NSError *error = [NSError
      errorWithDomain:@"google"
                 code:0
             userInfo:@{NSLocalizedDescriptionKey : @"Vungle doesn't support banner ads."}];
  [_connector adapter:self didFailAd:error];
}

- (void)loadAd {
  [[vungleHelper sharedInstance] loadAd:desiredPlacement];
}

- (void)getInterstitial {
  [vungleHelper
      parseServerParameters:[_connector credentials]
              networkExtras:[_connector networkExtras]
                     result:^void(NSDictionary *error, NSString *appId) {
                       if (error) {
                         [_connector
                               adapter:self
                             didFailAd:[NSError errorWithDomain:@"GADMAdapterVungleInterstitial"
                                                           code:0
                                                       userInfo:error]];
                         return;
                       }
                       desiredPlacement = [vungleHelper findPlacement:[_connector credentials]
                                                        networkExtras:[_connector networkExtras]];
                       if (!desiredPlacement) {
                         [_connector
                               adapter:self
                             didFailAd:[NSError errorWithDomain:@"GADMAdapterVungleInterstitial"
                                                           code:0
                                                       userInfo:@{
                                                         NSLocalizedDescriptionKey :
                                                             @"'placementID' not specified"
                                                       }]];
                         return;
                       }
                       waitingInit = YES;
                       [[vungleHelper sharedInstance] initWithAppId:appId];
                     }];
}

- (void)stopBeingDelegate {
  _connector = nil;
  [[vungleHelper sharedInstance] removeDelegate:self];
}

- (BOOL)isBannerAnimationOK:(GADMBannerAnimationType)animType {
  return YES;
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)rootViewController {
  if (![[vungleHelper sharedInstance] playAd:rootViewController
                                    delegate:self
                                      extras:[_connector networkExtras]]) {
    [_connector adapterDidDismissInterstitial:self];
  }
}

#pragma mark - vungleHelper delegates

@synthesize desiredPlacement;

@synthesize waitingInit;

- (void)initialized:(BOOL)isSuccess error:(NSError *)error {
  waitingInit = NO;
  if (isSuccess && desiredPlacement) {
    if (desiredPlacement) {
      [self loadAd];
    }
  } else {
    [_connector adapter:self didFailAd:error];
  }
}

- (void)adAvailable {
  [_connector adapterDidReceiveInterstitial:self];
}

- (void)willShowAd {
  [_connector adapterWillPresentInterstitial:self];
}

- (void)willCloseAd:(BOOL)completedView didDownload:(BOOL)didDownload {
  if (didDownload) {
    [_connector adapterDidGetAdClick:self];
    [_connector adapterWillLeaveApplication:self];
  }
  [_connector adapterWillDismissInterstitial:self];
}

- (void)didCloseAd:(BOOL)completedView didDownload:(BOOL)didDownload {
  [_connector adapterDidDismissInterstitial:self];
  desiredPlacement = nil;
}

@end
