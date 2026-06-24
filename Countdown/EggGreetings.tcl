###########################################################################################
#                      ____  ____  _     ____  _     ____ 	                          #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                          #
#                     | / \||    \| |   |  \/|| |   |    \	                          #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                          #
#                     \_/ \|\____/\____/\_/   \____/\____/	                          #
#                       asl_pls / irc.underx.org #aslpls    	                          #
#                                                                                         #
###########################################################################################
#
# EggGreetings.tcl - Standalone Christmas Quotes with adjustable timer variable.
# Clean text formatting optimized for traditional IRC clients.
#
###########################################################################################

namespace eval ::XmasQuotes {
    # CONFIGURATION
    # Target channels where the automation will broadcast.
    # Separate multiple channels with spaces, e.g., "#channel1 #channel2"
    variable target_chans "#aslpls"

    # Set the automation interval in minutes (e.g., 60 for every hour)
    variable interval_minutes 60

    # Bind public trigger
    bind pub - !xmasquote ::XmasQuotes::pub_xmasquote

    # Internal database of 103 premium Christmas quotes
    variable quotes [list \
        "\"I will honour Christmas in my heart, and try to keep it all the year.\" - Charles Dickens" \
        "\"Christmas is a tonic for our souls. It moves us to think of others rather than of ourselves.\" - B.C. Forbes" \
        "\"Christmas waves a magic wand over this world, and behold, everything is softer and more beautiful.\" - Norman Vincent Peale" \
        "\"Then the Grinch thought of something he hadn't before! What if Christmas, he thought, doesn't come from a store. What if Christmas... perhaps... means a little bit more!\" - Dr. Seuss" \
        "\"Christmas isn't just a day, it's a frame of mind.\" - Valentine Davies" \
        "\"It's not what's under the Christmas tree that matters, it's who's around it.\" - Charles M. Schulz" \
        "\"Christmas is a necessity. There has to be at least one day of the year to remind us that we're here for something besides ourselves.\" - Eric Sevareid" \
        "\"Gifts of time and love are surely the basic ingredients of a truly merry Christmas.\" - Peg Bracken" \
        "\"Christmas magic is silent. You don't hear it, you feel it. You know it. You believe it.\" - Kevin Alan Milne" \
        "\"One of the most glorious messes in the world is the mess created in the living room on Christmas Day. Don't clean it up too quickly.\" - Andy Rooney" \
        "\"Peace on earth will come to stay, when we live Christmas every day.\" - Helen Steiner Rice" \
        "\"Christmas is a season for kindling the fire for hospitality in the hall, the genial flame of charity in the heart.\" - Washington Irving" \
        "\"He who has not Christmas in his heart will never find it under a tree.\" - Roy L. Smith" \
        "\"My idea of Christmas, whether old-fashioned or modern, is very simple: loving others.\" - Bob Hope" \
        "\"Christmas is the day that holds all time together.\" - Alexander Smith" \
        "\"The best of all gifts around any Christmas tree: the presence of a happy family all wrapped up in each other.\" - Burton Hillis" \
        "\"Christmas is doing a little something extra for someone.\" - Charles M. Schulz" \
        "\"At Christmas, all roads lead home.\" - Marjorie Holmes" \
        "\"Christmas give us the opportunity to pause and reflect on the important things around us.\" - David Cameron" \
        "\"Christmas is a togethery sort of holiday.\" - A.A. Milne" \
        "\"A good conscience is a continual Christmas.\" - Benjamin Franklin" \
        "\"Love the giver more than the gift.\" - Brigham Young" \
        "\"Christmas works like diligence, it makes a short day long.\" - George Wither" \
        "\"The joy of brightening other lives becomes for us the magic of the holidays.\" - W.C. Jones" \
        "\"Like snowflakes, my Christmas memories gather and dance - each beautiful, unique, and too soon gone.\" - Deborah Whipp" \
        "\"The room was filled with the warm, sweet scent of pine, woodsmoke, and dynamic expectation.\" - Chelsea Mueller" \
        "\"Christmas time is cherished because it forces us to reset and spend energy on what truly counts.\" - Unknown" \
        "\"Unless we make Christmas an occasion to share our blessings, all the snow in Alaska won't make it white.\" - Bing Crosby" \
        "\"The main thing about Christmas is that it brings out the child in all of us.\" - Unknown" \
        "\"There is nothing cozier than a house lit up for the holidays when the world outside is cold.\" - Unknown" \
        "\"Christmas is a bridge. We need bridges as the river of time flows past.\" - Gladys Taber" \
        "\"Blessed is the season which engages the whole world in a conspiracy of love.\" - Hamilton Wright Mabie" \
        "\"The smell of pine needles, spruce, and the winter air is the true scent of December.\" - Unknown" \
        "\"Our hearts grow tender with childhood memories and love of kindred, and we are better throughout the year for having, in spirit, become a child again at Christmastime.\" - Laura Ingalls Wilder" \
        "\"The spirit of Christmas is the spirit of love and of generosity and of goodness.\" - Thomas S. Monson" \
        "\"For thousands of years, humanity has gathered to find warmth in the darkest days of the winter calendar.\" - Unknown" \
        "\"May you never be too grown up to search the skies on Christmas Eve.\" - Unknown" \
        "\"Christmas renewed is the spirit of youth returning to the weary heart.\" - Unknown" \
        "\"We open our hearts, we open our doors, and for a short moment, the world feels unified.\" - Unknown" \
        "\"The world has grown weary through the long year, but Christmas brings a fresh spark of hope.\" - Unknown" \
        "\"The best way to see Christmas is through the eyes of a child, where everything is magic.\" - Unknown" \
        "\"Small acts of kindness during the winter season echo loudly into the new year.\" - Unknown" \
        "\"The warmth of a hearth fire is multiplied when shared with friends returning from out of town.\" - Unknown" \
        "\"Let us keep Christmas beautiful without a thought of greed.\" - Ann Schultz" \
        "\"A holiday string of lights can brighten the darkest night and the heaviest spirit.\" - Unknown" \
        "\"Christmas is like candy; it slowly melts in your mouth sweetening every single taste bud, making you wish it could last forever.\" - Richelle E. Goodrich" \
        "\"The true wealth of the season is measured in moments, laughter, and community.\" - Unknown" \
        "\"When the snow falls and the music plays, the chaotic rush of the world fades into silence.\" - Unknown" \
        "\"A quiet evening by the tree is worth more than the grandest holiday gala.\" - Unknown" \
        "\"May the peace and joy of the season settle into your home and stay long after the decorations are put away.\" - Unknown" \
        "\"The magic of December lies in the quiet anticipation of the year's grand finale.\" - Unknown" \
        "\"Generosity of spirit is the finest coat you can wear against the winter freeze.\" - Unknown" \
        "\"No matter the distance, the traditions of home always find a way back to us in December.\" - Unknown" \
        "\"Christmas is the spirit of giving without a thought of getting.\" - Thomas S. Monson" \
        "\"The best tree decorations are the memories you've made with those you love.\" - Unknown" \
        "\"Christmas is a day of meaning and traditions, a special day spent in the warm circle of family and friends.\" - Margaret Thatcher" \
        "\"Nothing is as sweet as the sound of children laughing on a cold December morning.\" - Unknown" \
        "\"The kindness shared during December is a gift that keeps on giving all through the next year.\" - Unknown" \
        "\"The sparkle in a child's eyes is the truest light of the holiday season.\" - Unknown" \
        "\"Christmas night is a time for quiet reflection, gratitude, and a peaceful heart.\" - Unknown" \
        "\"The simplicity of winter forces us to value the simple warmth of our own homes.\" - Unknown" \
        "\"May your home be filled with the magic of the holidays and the warmth of family love.\" - Unknown" \
        "\"A little smile, a word of cheer, a bit of love from someone near, a little gift from one held dear, best wishes for the coming year.\" - John Greenleaf Whittier" \
        "\"The true joy of the season is found when we pause long enough to see it.\" - Unknown" \
        "\"Christmas is a canvas where we paint our finest memories of home and family.\" - Unknown" \
        "\"The world rests quiet under winter skies, waiting for the bright promise of a new year.\" - Unknown" \
        "\"May the holiday spirit fill your heart with hope and your home with endless laughter.\" - Unknown" \
        "\"The melody of Christmas carols has a unique way of bringing old memories back to life.\" - Unknown" \
        "\"There is no time more magical than when the first winter snow meets the glowing holiday lights.\" - Unknown" \
        "\"A shared meal around a warm table is the finest custom the season has to offer.\" - Unknown" \
        "\"Christmas is a day that holds all time together, connecting past dreams with future hopes.\" - Unknown" \
        "\"The finest presents are never wrapped in boxes; they are found in moments of true connection.\" - Unknown" \
        "\"Let us cherish the traditions that tie us to our past and anchor us in our future.\" - Unknown" \
        "\"The cool December breeze is easily met with the warm hospitality of an open door.\" - Unknown" \
        "\"Winter nights are long, but they are made bright by the joyful hearts gathering inside.\" - Unknown" \
        "\"May your days be merry and bright, and may all your Christmases be white.\" - Irving Berlin" \
        "\"The true meaning of the holidays shines bright in the quiet acts of unselfish charity.\" - Unknown" \
        "\"May the quiet beauty of a winter evening bring peace and comfort to your soul.\" - Unknown" \
        "\"There is a distinct comfort in returning to the simple holiday traditions of our youth.\" - Unknown" \
        "\"The greatest joy of the holidays is the sweet opportunity to tell others how much they matter.\" - Unknown" \
        "\"Let the spirit of love fill your home and leave no room for the chill of the outside world.\" - Unknown" \
        "\"Every card sent and every hand shaken is a beautiful sign of human connection.\" - Unknown" \
        "\"The dynamic energy of December reminds us that new beginnings are just around the corner.\" - Unknown" \
        "\"A festive heart finds beauty in every falling snowflake and every glowing window pane.\" - Unknown" \
        "\"May the harmony of the season stay with you long after the calendar turns.\" - Unknown" \
        "\"The finest shelter against the winter chill is a room filled with true friends.\" - Unknown" \
        "\"Christmas is not a time nor a season, but a state of mind. To cherish peace and goodwill is the real spirit.\" - Calvin Coolidge" \
        "\"The quiet countdown to the new year is best spent in the company of those we hold dear.\" - Unknown" \
        "\"May the festive cheer bring a light heart to your days and a calm spirit to your nights.\" - Unknown" \
        "\"The beauty of December is that it forces the entire busy world to take a collective breath.\" - Unknown" \
        "\"A small token of love given in December echoes with deep meaning throughout the seasons ahead.\" - Unknown" \
        "\"May your holiday table be crowded with family, filled with food, and rich with stories.\" - Unknown" \
        "\"The true wealth of a person is seen in the joy they bring to others during the winter season.\" - Unknown" \
        "\"Let us welcome the winter days with a spirit of gratitude and a heart open to joy.\" - Unknown" \
        "\"The simple magic of a decorated tree can bring wonder back to the oldest heart.\" - Unknown" \
        "\"May the peaceful glow of the season bring a quiet comfort to you and yours.\" - Unknown" \
        "\"The memories we construct during December become the internal warmth that carries us through spring.\" - Unknown" \
        "\"There is an elegant beauty in a silent winter night when the stars shine over the frost.\" - Unknown" \
        "\"May the holiday season bring a fresh perspective and a renewed sense of hope for the future.\" - Unknown" \
        "\"The finest music of the season is the sound of family gathering together after long absence.\" - Unknown" \
        "\"Let us wrap our hearts in kindness this month and distribute it freely wherever we go.\" - Unknown" \
        "\"A joyful Christmas season sets a beautiful foundation for a bright and prosperous new year.\" - Unknown" \
        "\"The ultimate magic of the holidays is that they remind us of what truly matters in life.\" - Unknown" \
    ]

    # Public command handler (!xmasquote)
    proc pub_xmasquote {nick uhost hand chan text} {
        variable quotes
        set selected [lindex $quotes [expr {int(rand() * [llength $quotes])}]]
        putquick "PRIVMSG $chan :\002\[Christmas \00303Bell\003\]\002 $selected"
        return 1
    }

    # Automated timer loop handler
    proc auto_xmasquote {} {
        global botnick
        variable quotes
        variable target_chans
        
        set selected [lindex $quotes [expr {int(rand() * [llength $quotes])}]]
        
        foreach chan [split $target_chans] {
            if {[validchan $chan] && [onchan $botnick $chan]} {
                putquick "PRIVMSG $chan :\[\00304Jingle\003 \00306Bell\003\] $selected"
            }
        }
        
        schedule_timer
    }

    # Helper function to safely schedule the next execution loop
    proc schedule_timer {} {
        variable interval_minutes
        
        # Check for existing instances to prevent duplicate running loops on multiple rehashes
        foreach t [utimers] {
            if {[string match "*::XmasQuotes::auto_xmasquote*" [lindex $t 1]]} { return }
        }
        
        set delay_seconds [expr {$interval_minutes * 60}]
        utimer $delay_seconds ::XmasQuotes::auto_xmasquote
    }

    # Initialize the automated loop cycle upon script loading/rehashing
    schedule_timer
    
    putlog "Loaded: EggGreetings.tcl with a customizable [set interval_minutes]-minute loop cycle active."
}
