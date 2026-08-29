#import "WolFox.h"

%ctor {
    [[WFAppManager sharedManager] initialize];
}
%init
