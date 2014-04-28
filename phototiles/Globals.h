//
//  Globals.h
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#define FLICKR_KEY                      @"1b6db46c56b01e30909721c65c3b3db6"
#define FLICKR_SECRET                   @"15421f53a4aa9231"
#define FLICKR_API_URL                  @"api.flickr.com"

#define FLICKR_PAGESIZE                 50

#define SNEAKY_USER_AGENT               @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36"

#define MINIMUM_IMAGE_DATA_SIZE_BYTES   500
#define MAXIMUM_IMAGE_DATA_SIZE_BYTES   350000

//every hour the blacklist is cleared just in case broken images finally get fixed on server
#define IMAGE_BLACKLIST_LIFESPAN        (60*60)

#define HTTP_SECURE                     @"https://"
