import Foundation

/// Represents a single emoji, its aliases, and its Unicode metadata.
public struct EmojiItem: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { "\(emoji)_\(name)" }
    public let emoji: String
    public let name: String
    public let aliases: [String]
    public let category: String

    public var primaryAlias: String {
        aliases.first ?? ":\(name.lowercased().replacingOccurrences(of: " ", with: "_")):"
    }

    public var unicodeHex: String {
        emoji.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
    }

    public init(emoji: String, name: String, aliases: [String], category: String = "Smileys") {
        self.emoji = emoji
        self.name = name
        self.aliases = aliases
        self.category = category
    }
}

/// Catalog of emoji trigger codes for expansion and reverse-engineering.
public enum EmojiCatalog {
    public struct Match: Sendable, Equatable {
        public let emoji: String
        public let alias: String
    }

    public static let categories: [String] = [
        "All", "Popular", "Smileys", "Gestures", "Nature", "Food", "Travel", "Celebration", "Objects", "Symbols"
    ]

    /// Master list of emojis with expressive synonyms.
    public static let all: [EmojiItem] = [
        // MARK: - Popular & Essentials
        EmojiItem(emoji: "🔥", name: "Fire", aliases: [":fire:", ":flame:", ":lit:", ":hot:"], category: "Popular"),
        EmojiItem(emoji: "❤️", name: "Red Heart", aliases: [":heart:", ":love:", ":red_heart:", ":redheart:"], category: "Popular"),
        EmojiItem(emoji: "❤️‍🔥", name: "Heart on Fire", aliases: [":heart_on_fire:", ":heartonfire:", ":fire_heart:"], category: "Popular"),
        EmojiItem(emoji: "👍", name: "Thumbs Up", aliases: [":thumbsup:", ":thumbs_up:", ":thumbs-up:", ":+1:", ":like:", ":yes:", ":ok:"], category: "Popular"),
        EmojiItem(emoji: "👎", name: "Thumbs Down", aliases: [":thumbsdown:", ":thumbs_down:", ":-1:", ":no:", ":dislike:"], category: "Popular"),
        EmojiItem(emoji: "😂", name: "Face with Tears of Joy", aliases: [":joy:", ":laugh:", ":laughing:", ":lol:", ":lmao:"], category: "Popular"),
        EmojiItem(emoji: "🤣", name: "Rolling on the Floor Laughing", aliases: [":rofl:", ":rolling_laugh:", ":crying_laughing:"], category: "Popular"),
        EmojiItem(emoji: "🌹", name: "Rose", aliases: [":rose:", ":flower_rose:"], category: "Nature"),
        EmojiItem(emoji: "🚀", name: "Rocket", aliases: [":rocket:", ":launch:", ":speed:", ":fast:"], category: "Popular"),
        EmojiItem(emoji: "✅", name: "Check Mark", aliases: [":check:", ":checkmark:", ":white_check_mark:", ":done:", ":verified:"], category: "Popular"),
        EmojiItem(emoji: "❌", name: "Cross Mark", aliases: [":cross:", ":x:", ":wrong:", ":error:", ":cancel:"], category: "Popular"),
        EmojiItem(emoji: "💯", name: "Hundred Points", aliases: [":100:", ":hundred:", ":perfect:"], category: "Popular"),
        EmojiItem(emoji: "🎉", name: "Party Popper", aliases: [":tada:", ":party:", ":celebration:", ":congrats:"], category: "Celebration"),
        EmojiItem(emoji: "🫡", name: "Saluting Face", aliases: [":salute:", ":saluting:", ":saluting_face:", ":respect:"], category: "Popular"),
        EmojiItem(emoji: "✨", name: "Sparkles", aliases: [":sparkles:", ":stars:", ":magic:", ":shiny:"], category: "Popular"),
        EmojiItem(emoji: "💡", name: "Light Bulb", aliases: [":bulb:", ":idea:", ":light:", ":insight:"], category: "Popular"),
        EmojiItem(emoji: "⚡", name: "High Voltage", aliases: [":zap:", ":lightning:", ":bolt:", ":power:"], category: "Popular"),
        EmojiItem(emoji: "👏", name: "Clapping Hands", aliases: [":clap:", ":applause:", ":bravo:"], category: "Popular"),
        EmojiItem(emoji: "🙌", name: "Raising Hands", aliases: [":raised_hands:", ":hooray:", ":celebrate:"], category: "Popular"),
        EmojiItem(emoji: "🤝", name: "Handshake", aliases: [":handshake:", ":deal:", ":agreement:"], category: "Popular"),
        EmojiItem(emoji: "👀", name: "Eyes", aliases: [":eyes:", ":look:", ":see:", ":watching:"], category: "Popular"),
        EmojiItem(emoji: "💀", name: "Skull", aliases: [":skull:", ":dead:", ":skeleton:"], category: "Popular"),
        EmojiItem(emoji: "💩", name: "Pile of Poo", aliases: [":poop:", ":poo:", ":crap:"], category: "Popular"),
        EmojiItem(emoji: "🥳", name: "Partying Face", aliases: [":partying:", ":party_face:", ":woohoo:"], category: "Popular"),
        EmojiItem(emoji: "🫶", name: "Heart Hands", aliases: [":heart_hands:", ":hearthands:", ":love_hands:"], category: "Popular"),
        EmojiItem(emoji: "🥹", name: "Face Holding Back Tears", aliases: [":holding_back_tears:", ":teary:", ":touched:"], category: "Popular"),
        EmojiItem(emoji: "🫠", name: "Melting Face", aliases: [":melting:", ":melting_face:", ":dissolve:"], category: "Popular"),
        EmojiItem(emoji: "🫨", name: "Shaking Face", aliases: [":shaking_face:", ":shocked_face:", ":vibrate:"], category: "Popular"),

        // MARK: - Smileys & Expressions
        EmojiItem(emoji: "😀", name: "Grinning Face", aliases: [":grinning:", ":grin:", ":happy_face:"], category: "Smileys"),
        EmojiItem(emoji: "😃", name: "Grinning Face with Big Eyes", aliases: [":smiley:", ":big_smile:"], category: "Smileys"),
        EmojiItem(emoji: "😄", name: "Grinning Face with Smiling Eyes", aliases: [":smile_eyes:", ":happy_eyes:"], category: "Smileys"),
        EmojiItem(emoji: "😁", name: "Beaming Face", aliases: [":beam:", ":beaming:"], category: "Smileys"),
        EmojiItem(emoji: "😆", name: "Grinning Squinting Face", aliases: [":laughing_squint:", ":satisfied:"], category: "Smileys"),
        EmojiItem(emoji: "😅", name: "Grinning Face with Sweat", aliases: [":sweat_smile:", ":relieved_sweat:"], category: "Smileys"),
        EmojiItem(emoji: "😊", name: "Smiling Face", aliases: [":smile:", ":smiling:", ":happy:", ":blush:"], category: "Smileys"),
        EmojiItem(emoji: "😇", name: "Smiling Face with Halo", aliases: [":innocent:", ":angel:", ":halo:"], category: "Smileys"),
        EmojiItem(emoji: "🥰", name: "Smiling Face with Hearts", aliases: [":smiling_face_with_hearts:", ":in_love:", ":hearts_smile:"], category: "Smileys"),
        EmojiItem(emoji: "😍", name: "Heart Eyes", aliases: [":heart_eyes:", ":hearteyes:", ":love_eyes:"], category: "Smileys"),
        EmojiItem(emoji: "🤩", name: "Star-Struck", aliases: [":star_struck:", ":starstruck:", ":amazed:"], category: "Smileys"),
        EmojiItem(emoji: "😘", name: "Face Blowing a Kiss", aliases: [":kissing_heart:", ":blow_kiss:", ":kiss:"], category: "Smileys"),
        EmojiItem(emoji: "😋", name: "Face Savoring Food", aliases: [":yum:", ":tasty:", ":delicious:"], category: "Smileys"),
        EmojiItem(emoji: "😛", name: "Face with Tongue", aliases: [":stuck_out_tongue:", ":tongue:"], category: "Smileys"),
        EmojiItem(emoji: "😜", name: "Winking Face with Tongue", aliases: [":wink_tongue:", ":crazy:", ":playful:"], category: "Smileys"),
        EmojiItem(emoji: "🤪", name: "Zany Face", aliases: [":zany:", ":goofy:", ":wild:"], category: "Smileys"),
        EmojiItem(emoji: "😝", name: "Squinting Face with Tongue", aliases: [":squint_tongue:", ":prank:"], category: "Smileys"),
        EmojiItem(emoji: "🤑", name: "Money-Mouth Face", aliases: [":money_face:", ":rich:", ":cash:"], category: "Smileys"),
        EmojiItem(emoji: "🤗", name: "Smiling Face with Open Hands", aliases: [":hugs:", ":hug:", ":warm:"], category: "Smileys"),
        EmojiItem(emoji: "🫣", name: "Face with Peeking Eye", aliases: [":peeking_face:", ":peek:", ":scared_peek:"], category: "Smileys"),
        EmojiItem(emoji: "🫢", name: "Face with Open Eyes and Hand Over Mouth", aliases: [":gasp:", ":hand_over_mouth:"], category: "Smileys"),
        EmojiItem(emoji: "🤫", name: "Shushing Face", aliases: [":shush:", ":quiet:", ":secret:"], category: "Smileys"),
        EmojiItem(emoji: "🤔", name: "Thinking Face", aliases: [":think:", ":thinking:", ":hmm:", ":ponder:"], category: "Smileys"),
        EmojiItem(emoji: "🤐", name: "Zipper-Mouth Face", aliases: [":zipper_mouth:", ":sealed:", ":quiet_mouth:"], category: "Smileys"),
        EmojiItem(emoji: "🤨", name: "Face with Raised Eyebrow", aliases: [":eyebrow:", ":suspicious:", ":doubt:"], category: "Smileys"),
        EmojiItem(emoji: "😐", name: "Neutral Face", aliases: [":neutral:", ":meh:", ":poker_face:"], category: "Smileys"),
        EmojiItem(emoji: "😑", name: "Expressionless Face", aliases: [":expressionless:", ":blank:"], category: "Smileys"),
        EmojiItem(emoji: "😶", name: "Face Without Mouth", aliases: [":no_mouth:", ":silent:"], category: "Smileys"),
        EmojiItem(emoji: "😏", name: "Smirking Face", aliases: [":smirk:", ":smug:"], category: "Smileys"),
        EmojiItem(emoji: "😒", name: "Unamused Face", aliases: [":unamused:", ":side_eye:", ":unimpressed:"], category: "Smileys"),
        EmojiItem(emoji: "🙄", name: "Face with Rolling Eyes", aliases: [":rolling_eyes:", ":eyeroll:", ":whatever:"], category: "Smileys"),
        EmojiItem(emoji: "😬", name: "Grimacing Face", aliases: [":grimacing:", ":cringe:", ":awkward:"], category: "Smileys"),
        EmojiItem(emoji: "🤥", name: "Lying Face", aliases: [":lying_face:", ":pinocchio:", ":liar:"], category: "Smileys"),
        EmojiItem(emoji: "😌", name: "Relieved Face", aliases: [":relieved:", ":peaceful:", ":calm:"], category: "Smileys"),
        EmojiItem(emoji: "😔", name: "Pensive Face", aliases: [":pensive:", ":sad:", ":down:"], category: "Smileys"),
        EmojiItem(emoji: "😪", name: "Sleepy Face", aliases: [":sleepy:", ":tired_face:"], category: "Smileys"),
        EmojiItem(emoji: "🤤", name: "Drooling Face", aliases: [":drool:", ":drooling:"], category: "Smileys"),
        EmojiItem(emoji: "😴", name: "Sleeping Face", aliases: [":sleeping:", ":zzz:", ":asleep:"], category: "Smileys"),
        EmojiItem(emoji: "😷", name: "Face with Medical Mask", aliases: [":mask:", ":sick:", ":covid:"], category: "Smileys"),
        EmojiItem(emoji: "🤒", name: "Face with Thermometer", aliases: [":thermometer_face:", ":fever:"], category: "Smileys"),
        EmojiItem(emoji: "🤕", name: "Face with Head-Bandage", aliases: [":head_bandage:", ":hurt:"], category: "Smileys"),
        EmojiItem(emoji: "🤢", name: "Nauseated Face", aliases: [":nauseated:", ":gross:", ":green_face:"], category: "Smileys"),
        EmojiItem(emoji: "🤮", name: "Face Vomiting", aliases: [":vomit:", ":puke:"], category: "Smileys"),
        EmojiItem(emoji: "🤧", name: "Sneezing Face", aliases: [":sneeze:", ":achoo:"], category: "Smileys"),
        EmojiItem(emoji: "🥵", name: "Hot Face", aliases: [":hot_face:", ":overheated:", ":sweating:"], category: "Smileys"),
        EmojiItem(emoji: "🥶", name: "Cold Face", aliases: [":cold_face:", ":freezing:", ":ice_cold:"], category: "Smileys"),
        EmojiItem(emoji: "🥴", name: "Woozy Face", aliases: [":woozy:", ":tipsy:", ":dizzy_smile:"], category: "Smileys"),
        EmojiItem(emoji: "😵", name: "Face with Crossed-Out Eyes", aliases: [":dizzy_face:", ":knocked_out:"], category: "Smileys"),
        EmojiItem(emoji: "🤯", name: "Exploding Head", aliases: [":exploding_head:", ":mindblown:", ":mind_blown:"], category: "Smileys"),
        EmojiItem(emoji: "🤠", name: "Cowboy Hat Face", aliases: [":cowboy:", ":howdy:"], category: "Smileys"),
        EmojiItem(emoji: "😎", name: "Smiling Face with Sunglasses", aliases: [":cool:", ":sunglasses:", ":chill:"], category: "Smileys"),
        EmojiItem(emoji: "🤓", name: "Nerd Face", aliases: [":nerd:", ":geek:", ":glasses:"], category: "Smileys"),
        EmojiItem(emoji: "🧐", name: "Face with Monocle", aliases: [":monocle:", ":curious:", ":investigate:"], category: "Smileys"),
        EmojiItem(emoji: "😕", name: "Confused Face", aliases: [":confused:", ":baffled:"], category: "Smileys"),
        EmojiItem(emoji: "😟", name: "Worried Face", aliases: [":worried:", ":nervous:"], category: "Smileys"),
        EmojiItem(emoji: "🙁", name: "Slightly Frowning Face", aliases: [":frowning:", ":unhappy:"], category: "Smileys"),
        EmojiItem(emoji: "😮", name: "Face with Open Mouth", aliases: [":open_mouth:", ":surprise:"], category: "Smileys"),
        EmojiItem(emoji: "😲", name: "Astonished Face", aliases: [":astonished:", ":shocked:"], category: "Smileys"),
        EmojiItem(emoji: "😳", name: "Flushed Face", aliases: [":flushed:", ":embarrassed:", ":blushing:"], category: "Smileys"),
        EmojiItem(emoji: "🥺", name: "Pleading Face", aliases: [":pleading:", ":puppy_eyes:", ":begging:"], category: "Smileys"),
        EmojiItem(emoji: "😦", name: "Frowning Face with Open Mouth", aliases: [":frowning_open:", ":gasp_face:"], category: "Smileys"),
        EmojiItem(emoji: "😨", name: "Fearful Face", aliases: [":fearful:", ":scared:"], category: "Smileys"),
        EmojiItem(emoji: "😰", name: "Anxious Face with Sweat", aliases: [":anxious:", ":sweat_fear:"], category: "Smileys"),
        EmojiItem(emoji: "😥", name: "Sad but Relieved Face", aliases: [":relieved_sad:", ":phew:"], category: "Smileys"),
        EmojiItem(emoji: "😢", name: "Crying Face", aliases: [":cry:", ":tear:", ":sad_tear:"], category: "Smileys"),
        EmojiItem(emoji: "😭", name: "Loudly Crying Face", aliases: [":sob:", ":crying:", ":bawling:"], category: "Smileys"),
        EmojiItem(emoji: "😱", name: "Face Screaming in Fear", aliases: [":scream:", ":horror:", ":omg:"], category: "Smileys"),
        EmojiItem(emoji: "😖", name: "Confounded Face", aliases: [":confounded:", ":frustrated:"], category: "Smileys"),
        EmojiItem(emoji: "😣", name: "Persevering Face", aliases: [":persevere:", ":struggling:"], category: "Smileys"),
        EmojiItem(emoji: "😞", name: "Disappointed Face", aliases: [":disappointed:", ":letdown:"], category: "Smileys"),
        EmojiItem(emoji: "😓", name: "Downcast Face with Sweat", aliases: [":downcast:", ":hard_work:"], category: "Smileys"),
        EmojiItem(emoji: "😩", name: "Weary Face", aliases: [":weary:", ":exhausted:"], category: "Smileys"),
        EmojiItem(emoji: "😫", name: "Tired Face", aliases: [":tired:", ":done:"], category: "Smileys"),
        EmojiItem(emoji: "🥱", name: "Yawning Face", aliases: [":yawn:", ":sleepy_yawn:"], category: "Smileys"),
        EmojiItem(emoji: "😤", name: "Face with Steam From Nose", aliases: [":triumph:", ":proud_steam:"], category: "Smileys"),
        EmojiItem(emoji: "😡", name: "Enraged Face", aliases: [":rage:", ":angry:", ":mad:"], category: "Smileys"),
        EmojiItem(emoji: "😠", name: "Angry Face", aliases: [":angry_face:", ":annoyed:"], category: "Smileys"),
        EmojiItem(emoji: "🤬", name: "Face with Symbols on Mouth", aliases: [":cursing:", ":swearing:", ":swear:"], category: "Smileys"),
        EmojiItem(emoji: "😈", name: "Smiling Face with Horns", aliases: [":devil:", ":mischievous:"], category: "Smileys"),
        EmojiItem(emoji: "👿", name: "Angry Face with Horns", aliases: [":imp:", ":evil:"], category: "Smileys"),
        EmojiItem(emoji: "☠️", name: "Skull and Crossbones", aliases: [":skull_crossbones:", ":pirate:", ":danger:"], category: "Smileys"),
        EmojiItem(emoji: "🤡", name: "Clown Face", aliases: [":clown:", ":fool:"], category: "Smileys"),
        EmojiItem(emoji: "👻", name: "Ghost", aliases: [":ghost:", ":boo:", ":spooky:"], category: "Smileys"),
        EmojiItem(emoji: "👽", name: "Alien", aliases: [":alien:", ":ufo_creature:"], category: "Smileys"),
        EmojiItem(emoji: "🤖", name: "Robot", aliases: [":robot:", ":bot:", ":android:"], category: "Smileys"),

        // MARK: - Gestures & People
        EmojiItem(emoji: "👋", name: "Waving Hand", aliases: [":wave:", ":hello:", ":bye:", ":hi:"], category: "Gestures"),
        EmojiItem(emoji: "🤚", name: "Raised Back of Hand", aliases: [":raised_back_of_hand:"], category: "Gestures"),
        EmojiItem(emoji: "🖐️", name: "Hand with Fingers Splayed", aliases: [":fingers_splayed:", ":high_five:"], category: "Gestures"),
        EmojiItem(emoji: "✋", name: "Raised Hand", aliases: [":hand:", ":stop:", ":halt:"], category: "Gestures"),
        EmojiItem(emoji: "🖖", name: "Vulcan Salute", aliases: [":vulcan:", ":spock:", ":live_long:"], category: "Gestures"),
        EmojiItem(emoji: "👌", name: "OK Hand", aliases: [":ok_hand:", ":okay:", ":perfect_hand:"], category: "Gestures"),
        EmojiItem(emoji: "🤌", name: "Pinched Fingers", aliases: [":pinched_fingers:", ":italian:", ":mamma_mia:"], category: "Gestures"),
        EmojiItem(emoji: "🤏", name: "Pinching Hand", aliases: [":pinching:", ":tiny:", ":little_bit:"], category: "Gestures"),
        EmojiItem(emoji: "✌️", name: "Victory Hand", aliases: [":peace:", ":victory:", ":v:"], category: "Gestures"),
        EmojiItem(emoji: "🤞", name: "Crossed Fingers", aliases: [":crossed_fingers:", ":fingers_crossed:", ":luck:"], category: "Gestures"),
        EmojiItem(emoji: "🫰", name: "Hand with Index and Thumb Crossed", aliases: [":korean_heart:", ":money_hand:", ":mini_heart:"], category: "Gestures"),
        EmojiItem(emoji: "🤟", name: "Love-You Gesture", aliases: [":love_you:", ":ily:"], category: "Gestures"),
        EmojiItem(emoji: "🤘", name: "Sign of the Horns", aliases: [":rock:", ":rock_on:", ":metal:"], category: "Gestures"),
        EmojiItem(emoji: "🤙", name: "Call Me Hand", aliases: [":call_me:", ":shaka:"], category: "Gestures"),
        EmojiItem(emoji: "👈", name: "Backhand Pointing Left", aliases: [":point_left:", ":left:"], category: "Gestures"),
        EmojiItem(emoji: "👉", name: "Backhand Pointing Right", aliases: [":point_right:", ":right:"], category: "Gestures"),
        EmojiItem(emoji: "👆", name: "Backhand Pointing Up", aliases: [":point_up:", ":above:"], category: "Gestures"),
        EmojiItem(emoji: "👇", name: "Backhand Pointing Down", aliases: [":point_down:", ":below:"], category: "Gestures"),
        EmojiItem(emoji: "☝️", name: "Index Pointing Up", aliases: [":one_point:", ":attention:"], category: "Gestures"),
        EmojiItem(emoji: "✊", name: "Raised Fist", aliases: [":fist:", ":solidarity:"], category: "Gestures"),
        EmojiItem(emoji: "👊", name: "Oncoming Fist", aliases: [":fist_bump:", ":punch:"], category: "Gestures"),
        EmojiItem(emoji: "🤛", name: "Left-Facing Fist", aliases: [":left_fist:"], category: "Gestures"),
        EmojiItem(emoji: "🤜", name: "Right-Facing Fist", aliases: [":right_fist:"], category: "Gestures"),
        EmojiItem(emoji: "🙏", name: "Folded Hands", aliases: [":pray:", ":thanks:", ":please:", ":thankyou:"], category: "Gestures"),
        EmojiItem(emoji: "✍️", name: "Writing Hand", aliases: [":writing:", ":pen_hand:"], category: "Gestures"),
        EmojiItem(emoji: "💪", name: "Flexed Biceps", aliases: [":muscle:", ":strong:", ":flex:"], category: "Gestures"),
        EmojiItem(emoji: "🧠", name: "Brain", aliases: [":brain:", ":smart:", ":intellect:"], category: "Gestures"),
        EmojiItem(emoji: "🧑‍💻", name: "Technologist", aliases: [":coder:", ":developer:", ":programmer:"], category: "Gestures"),

        // MARK: - Nature & Animals
        EmojiItem(emoji: "🥀", name: "Wilted Flower", aliases: [":wilted_flower:", ":dead_flower:"], category: "Nature"),
        EmojiItem(emoji: "🌺", name: "Hibiscus", aliases: [":hibiscus:", ":flower:"], category: "Nature"),
        EmojiItem(emoji: "🌸", name: "Cherry Blossom", aliases: [":cherry_blossom:", ":sakura:"], category: "Nature"),
        EmojiItem(emoji: "🌻", name: "Sunflower", aliases: [":sunflower:", ":yellow_flower:"], category: "Nature"),
        EmojiItem(emoji: "🌼", name: "Blossom", aliases: [":blossom:", ":daisy:"], category: "Nature"),
        EmojiItem(emoji: "🌷", name: "Tulip", aliases: [":tulip:"], category: "Nature"),
        EmojiItem(emoji: "🌱", name: "Seedling", aliases: [":seedling:", ":plant:", ":grow:"], category: "Nature"),
        EmojiItem(emoji: "🪴", name: "Potted Plant", aliases: [":potted_plant:", ":houseplant:"], category: "Nature"),
        EmojiItem(emoji: "🌲", name: "Evergreen Tree", aliases: [":tree:", ":evergreen:", ":pine:"], category: "Nature"),
        EmojiItem(emoji: "🌳", name: "Deciduous Tree", aliases: [":deciduous_tree:", ":nature_tree:"], category: "Nature"),
        EmojiItem(emoji: "🌴", name: "Palm Tree", aliases: [":palm_tree:", ":palm:", ":tropical:"], category: "Nature"),
        EmojiItem(emoji: "🌵", name: "Cactus", aliases: [":cactus:", ":desert_plant:"], category: "Nature"),
        EmojiItem(emoji: "🍀", name: "Four Leaf Clover", aliases: [":clover:", ":lucky:", ":four_leaf_clover:"], category: "Nature"),
        EmojiItem(emoji: "🍁", name: "Maple Leaf", aliases: [":maple_leaf:", ":autumn:", ":canada:"], category: "Nature"),
        EmojiItem(emoji: "🍂", name: "Fallen Leaf", aliases: [":fallen_leaf:", ":fall:"], category: "Nature"),
        EmojiItem(emoji: "🍃", name: "Leaf Fluttering in Wind", aliases: [":leaf:", ":breeze:"], category: "Nature"),
        EmojiItem(emoji: "🍄", name: "Mushroom", aliases: [":mushroom:", ":shroom:"], category: "Nature"),
        EmojiItem(emoji: "🐶", name: "Dog Face", aliases: [":dog:", ":puppy:", ":canine:"], category: "Nature"),
        EmojiItem(emoji: "🐱", name: "Cat Face", aliases: [":cat:", ":kitty:", ":feline:"], category: "Nature"),
        EmojiItem(emoji: "🐭", name: "Mouse Face", aliases: [":mouse:", ":rodent:"], category: "Nature"),
        EmojiItem(emoji: "🐰", name: "Rabbit Face", aliases: [":rabbit:", ":bunny:"], category: "Nature"),
        EmojiItem(emoji: "🦊", name: "Fox", aliases: [":fox:", ":cunning:"], category: "Nature"),
        EmojiItem(emoji: "🐻", name: "Bear", aliases: [":bear:", ":grizzly:"], category: "Nature"),
        EmojiItem(emoji: "🐼", name: "Panda", aliases: [":panda:", ":panda_bear:"], category: "Nature"),
        EmojiItem(emoji: "🐨", name: "Koala", aliases: [":koala:"], category: "Nature"),
        EmojiItem(emoji: "🦁", name: "Lion", aliases: [":lion:", ":king:"], category: "Nature"),
        EmojiItem(emoji: "🐯", name: "Tiger Face", aliases: [":tiger:"], category: "Nature"),
        EmojiItem(emoji: "🦄", name: "Unicorn", aliases: [":unicorn:", ":fantasy:"], category: "Nature"),
        EmojiItem(emoji: "🦅", name: "Eagle", aliases: [":eagle:"], category: "Nature"),
        EmojiItem(emoji: "🦉", name: "Owl", aliases: [":owl:", ":wise:"], category: "Nature"),
        EmojiItem(emoji: "🦋", name: "Butterfly", aliases: [":butterfly:", ":flutter:"], category: "Nature"),
        EmojiItem(emoji: "🐝", name: "Honeybee", aliases: [":bee:", ":honeybee:"], category: "Nature"),
        EmojiItem(emoji: "🐬", name: "Dolphin", aliases: [":dolphin:"], category: "Nature"),
        EmojiItem(emoji: "🐳", name: "Spouting Whale", aliases: [":whale:", ":spout:"], category: "Nature"),
        EmojiItem(emoji: "🦈", name: "Shark", aliases: [":shark:"], category: "Nature"),

        // MARK: - Food & Drink
        EmojiItem(emoji: "🍎", name: "Red Apple", aliases: [":apple:", ":red_apple:"], category: "Food"),
        EmojiItem(emoji: "🍏", name: "Green Apple", aliases: [":green_apple:"], category: "Food"),
        EmojiItem(emoji: "🍊", name: "Tangerine", aliases: [":orange:", ":tangerine:"], category: "Food"),
        EmojiItem(emoji: "🍋", name: "Lemon", aliases: [":lemon:", ":sour:"], category: "Food"),
        EmojiItem(emoji: "🍌", name: "Banana", aliases: [":banana:"], category: "Food"),
        EmojiItem(emoji: "🍉", name: "Watermelon", aliases: [":watermelon:"], category: "Food"),
        EmojiItem(emoji: "🍇", name: "Grapes", aliases: [":grapes:"], category: "Food"),
        EmojiItem(emoji: "🍓", name: "Strawberry", aliases: [":strawberry:"], category: "Food"),
        EmojiItem(emoji: "🫐", name: "Blueberries", aliases: [":blueberry:", ":blueberries:"], category: "Food"),
        EmojiItem(emoji: "🍒", name: "Cherries", aliases: [":cherries:", ":cherry:"], category: "Food"),
        EmojiItem(emoji: "🍑", name: "Peach", aliases: [":peach:"], category: "Food"),
        EmojiItem(emoji: "🥭", name: "Mango", aliases: [":mango:"], category: "Food"),
        EmojiItem(emoji: "🍍", name: "Pineapple", aliases: [":pineapple:"], category: "Food"),
        EmojiItem(emoji: "🥑", name: "Avocado", aliases: [":avocado:"], category: "Food"),
        EmojiItem(emoji: "🥦", name: "Broccoli", aliases: [":broccoli:", ":greens:"], category: "Food"),
        EmojiItem(emoji: "🌽", name: "Ear of Corn", aliases: [":corn:"], category: "Food"),
        EmojiItem(emoji: "🥕", name: "Carrot", aliases: [":carrot:"], category: "Food"),
        EmojiItem(emoji: "🍞", name: "Bread", aliases: [":bread:", ":loaf:"], category: "Food"),
        EmojiItem(emoji: "🥐", name: "Croissant", aliases: [":croissant:", ":pastry:"], category: "Food"),
        EmojiItem(emoji: "🧀", name: "Cheese Wedge", aliases: [":cheese:"], category: "Food"),
        EmojiItem(emoji: "🍳", name: "Cooking", aliases: [":egg:", ":fried_egg:"], category: "Food"),
        EmojiItem(emoji: "🥞", name: "Pancakes", aliases: [":pancakes:", ":hotcakes:"], category: "Food"),
        EmojiItem(emoji: "🧇", name: "Waffle", aliases: [":waffle:"], category: "Food"),
        EmojiItem(emoji: "🥓", name: "Bacon", aliases: [":bacon:"], category: "Food"),
        EmojiItem(emoji: "🥩", name: "Cut of Meat", aliases: [":meat:", ":steak:"], category: "Food"),
        EmojiItem(emoji: "🍔", name: "Hamburger", aliases: [":burger:", ":hamburger:"], category: "Food"),
        EmojiItem(emoji: "🍟", name: "French Fries", aliases: [":fries:", ":french_fries:"], category: "Food"),
        EmojiItem(emoji: "🍕", name: "Pizza", aliases: [":pizza:"], category: "Food"),
        EmojiItem(emoji: "🌮", name: "Taco", aliases: [":taco:"], category: "Food"),
        EmojiItem(emoji: "🌯", name: "Burrito", aliases: [":burrito:"], category: "Food"),
        EmojiItem(emoji: "🍜", name: "Steaming Bowl", aliases: [":ramen:", ":noodles:"], category: "Food"),
        EmojiItem(emoji: "🍝", name: "Spaghetti", aliases: [":pasta:", ":spaghetti:"], category: "Food"),
        EmojiItem(emoji: "🍣", name: "Sushi", aliases: [":sushi:"], category: "Food"),
        EmojiItem(emoji: "🍦", name: "Soft Ice Cream", aliases: [":ice_cream:", ":icecream:"], category: "Food"),
        EmojiItem(emoji: "🍰", name: "Shortcake", aliases: [":cake:", ":sweet:"], category: "Food"),
        EmojiItem(emoji: "🎂", name: "Birthday Cake", aliases: [":birthday:", ":birthday_cake:"], category: "Food"),
        EmojiItem(emoji: "🍩", name: "Doughnut", aliases: [":donut:", ":doughnut:"], category: "Food"),
        EmojiItem(emoji: "🍪", name: "Cookie", aliases: [":cookie:", ":biscuit:"], category: "Food"),
        EmojiItem(emoji: "🍫", name: "Chocolate Bar", aliases: [":chocolate:", ":candy_bar:"], category: "Food"),
        EmojiItem(emoji: "🍿", name: "Popcorn", aliases: [":popcorn:"], category: "Food"),
        EmojiItem(emoji: "☕", name: "Hot Beverage", aliases: [":coffee:", ":tea:", ":espresso:"], category: "Food"),
        EmojiItem(emoji: "🧋", name: "Bubble Tea", aliases: [":boba:", ":bubble_tea:"], category: "Food"),
        EmojiItem(emoji: "🍺", name: "Beer Mug", aliases: [":beer:", ":cheers:"], category: "Food"),
        EmojiItem(emoji: "🍻", name: "Clinking Beer Mugs", aliases: [":beers:", ":clinking_beer:"], category: "Food"),
        EmojiItem(emoji: "🥂", name: "Clinking Glasses", aliases: [":champagne:", ":toast:"], category: "Food"),
        EmojiItem(emoji: "🍷", name: "Wine Glass", aliases: [":wine:"], category: "Food"),

        // MARK: - Travel & Places
        EmojiItem(emoji: "✈️", name: "Airplane", aliases: [":airplane:", ":flight:", ":fly:"], category: "Travel"),
        EmojiItem(emoji: "🚁", name: "Helicopter", aliases: [":helicopter:"], category: "Travel"),
        EmojiItem(emoji: "🚗", name: "Automobile", aliases: [":car:", ":drive:"], category: "Travel"),
        EmojiItem(emoji: "🚕", name: "Taxi", aliases: [":taxi:", ":cab:"], category: "Travel"),
        EmojiItem(emoji: "🏎️", name: "Racing Car", aliases: [":racing_car:", ":f1:"], category: "Travel"),
        EmojiItem(emoji: "🚲", name: "Bicycle", aliases: [":bike:", ":bicycle:"], category: "Travel"),
        EmojiItem(emoji: "🚆", name: "Train", aliases: [":train:", ":metro:"], category: "Travel"),
        EmojiItem(emoji: "🛳️", name: "Passenger Ship", aliases: [":ship:", ":cruise:"], category: "Travel"),
        EmojiItem(emoji: "🛸", name: "Flying Saucer", aliases: [":ufo:", ":flying_saucer:"], category: "Travel"),
        EmojiItem(emoji: "🏠", name: "House", aliases: [":house:", ":home:"], category: "Travel"),
        EmojiItem(emoji: "🏢", name: "Office Building", aliases: [":office:", ":workplace:"], category: "Travel"),
        EmojiItem(emoji: "🏰", name: "Castle", aliases: [":castle:"], category: "Travel"),
        EmojiItem(emoji: "🗽", name: "Statue of Liberty", aliases: [":liberty:", ":statue_of_liberty:"], category: "Travel"),
        EmojiItem(emoji: "🌍", name: "Globe", aliases: [":earth:", ":globe:", ":world:"], category: "Travel"),
        EmojiItem(emoji: "☀️", name: "Sun", aliases: [":sun:", ":sunny:", ":warm:"], category: "Travel"),
        EmojiItem(emoji: "🌙", name: "Crescent Moon", aliases: [":moon:", ":night:"], category: "Travel"),
        EmojiItem(emoji: "☁️", name: "Cloud", aliases: [":cloud:", ":cloudy:"], category: "Travel"),
        EmojiItem(emoji: "🌧️", name: "Cloud with Rain", aliases: [":rain:", ":rainy:"], category: "Travel"),
        EmojiItem(emoji: "❄️", name: "Snowflake", aliases: [":snow:", ":snowflake:", ":winter:"], category: "Travel"),
        EmojiItem(emoji: "🌈", name: "Rainbow", aliases: [":rainbow:"], category: "Travel"),
        EmojiItem(emoji: "🏖️", name: "Beach with Umbrella", aliases: [":beach:", ":vacation:"], category: "Travel"),
        EmojiItem(emoji: "🏔️", name: "Snow-Capped Mountain", aliases: [":mountain:", ":alps:"], category: "Travel"),

        // MARK: - Objects & Tools
        EmojiItem(emoji: "💻", name: "Laptop", aliases: [":macbook:", ":laptop:", ":computer:"], category: "Objects"),
        EmojiItem(emoji: "🖥️", name: "Desktop Computer", aliases: [":desktop:", ":monitor:", ":imac:"], category: "Objects"),
        EmojiItem(emoji: "📱", name: "Mobile Phone", aliases: [":iphone:", ":phone:", ":mobile:"], category: "Objects"),
        EmojiItem(emoji: "⌨️", name: "Keyboard", aliases: [":keyboard:", ":typing:"], category: "Objects"),
        EmojiItem(emoji: "🖱️", name: "Computer Mouse", aliases: [":mouse_device:", ":trackpad:"], category: "Objects"),
        EmojiItem(emoji: "🔋", name: "Battery", aliases: [":battery:", ":charge:"], category: "Objects"),
        EmojiItem(emoji: "🔍", name: "Magnifying Glass", aliases: [":search:", ":find:", ":magnify:"], category: "Objects"),
        EmojiItem(emoji: "🔒", name: "Locked", aliases: [":lock:", ":locked:", ":secure:"], category: "Objects"),
        EmojiItem(emoji: "🔓", name: "Unlocked", aliases: [":unlock:", ":open_lock:"], category: "Objects"),
        EmojiItem(emoji: "🔑", name: "Key", aliases: [":key:", ":access:"], category: "Objects"),
        EmojiItem(emoji: "🛠️", name: "Hammer and Wrench", aliases: [":tools:", ":settings:", ":repair:"], category: "Objects"),
        EmojiItem(emoji: "⚙️", name: "Gear", aliases: [":gear:", ":cog:", ":config:"], category: "Objects"),
        EmojiItem(emoji: "📦", name: "Package", aliases: [":box:", ":package:", ":delivery:"], category: "Objects"),
        EmojiItem(emoji: "📝", name: "Memo", aliases: [":memo:", ":note:", ":write:"], category: "Objects"),
        EmojiItem(emoji: "📁", name: "File Folder", aliases: [":folder:", ":directory:"], category: "Objects"),
        EmojiItem(emoji: "📅", name: "Calendar", aliases: [":calendar:", ":date:", ":schedule:"], category: "Objects"),
        EmojiItem(emoji: "📌", name: "Pushpin", aliases: [":pin:", ":pushpin:", ":pinned:"], category: "Objects"),
        EmojiItem(emoji: "📎", name: "Paperclip", aliases: [":paperclip:", ":attachment:"], category: "Objects"),
        EmojiItem(emoji: "💰", name: "Money Bag", aliases: [":money:", ":moneybag:", ":dollars:"], category: "Objects"),
        EmojiItem(emoji: "💳", name: "Credit Card", aliases: [":credit_card:", ":card:", ":payment:"], category: "Objects"),
        EmojiItem(emoji: "✉️", name: "Envelope", aliases: [":envelope:", ":mail:", ":message:"], category: "Objects"),

        // MARK: - Celebration & Activities
        EmojiItem(emoji: "🎈", name: "Balloon", aliases: [":balloon:", ":party_balloon:"], category: "Celebration"),
        EmojiItem(emoji: "🎁", name: "Wrapped Gift", aliases: [":gift:", ":present:"], category: "Celebration"),
        EmojiItem(emoji: "🏆", name: "Trophy", aliases: [":trophy:", ":winner:", ":first_place:"], category: "Celebration"),
        EmojiItem(emoji: "🥇", name: "1st Place Medal", aliases: [":gold_medal:", ":first:", ":gold:"], category: "Celebration"),
        EmojiItem(emoji: "🥈", name: "2nd Place Medal", aliases: [":silver_medal:", ":second:", ":silver:"], category: "Celebration"),
        EmojiItem(emoji: "🥉", name: "3rd Place Medal", aliases: [":bronze_medal:", ":third:", ":bronze:"], category: "Celebration"),
        EmojiItem(emoji: "⚽", name: "Soccer Ball", aliases: [":soccer:", ":football:"], category: "Celebration"),
        EmojiItem(emoji: "🏀", name: "Basketball", aliases: [":basketball:"], category: "Celebration"),
        EmojiItem(emoji: "🎾", name: "Tennis", aliases: [":tennis:"], category: "Celebration"),
        EmojiItem(emoji: "🎮", name: "Video Game", aliases: [":game:", ":controller:", ":gaming:"], category: "Celebration"),
        EmojiItem(emoji: "🎨", name: "Artist Palette", aliases: [":art:", ":design:", ":palette:"], category: "Celebration"),
        EmojiItem(emoji: "🎬", name: "Clapper Board", aliases: [":movie:", ":film:", ":cinema:"], category: "Celebration"),
        EmojiItem(emoji: "🎵", name: "Musical Note", aliases: [":music:", ":note:", ":song:"], category: "Celebration"),
        EmojiItem(emoji: "🎸", name: "Guitar", aliases: [":guitar:", ":rock_guitar:"], category: "Celebration"),

        // MARK: - Symbols
        EmojiItem(emoji: "⭐", name: "Star", aliases: [":star:", ":gold_star:", ":favorite:"], category: "Symbols"),
        EmojiItem(emoji: "🌟", name: "Glowing Star", aliases: [":glowing_star:", ":bright:"], category: "Symbols"),
        EmojiItem(emoji: "💥", name: "Collision", aliases: [":boom:", ":collision:", ":bang:"], category: "Symbols"),
        EmojiItem(emoji: "💔", name: "Broken Heart", aliases: [":broken_heart:", ":heartbreak:"], category: "Symbols"),
        EmojiItem(emoji: "🧡", name: "Orange Heart", aliases: [":orange_heart:"], category: "Symbols"),
        EmojiItem(emoji: "💛", name: "Yellow Heart", aliases: [":yellow_heart:"], category: "Symbols"),
        EmojiItem(emoji: "💚", name: "Green Heart", aliases: [":green_heart:"], category: "Symbols"),
        EmojiItem(emoji: "💙", name: "Blue Heart", aliases: [":blue_heart:"], category: "Symbols"),
        EmojiItem(emoji: "💜", name: "Purple Heart", aliases: [":purple_heart:"], category: "Symbols"),
        EmojiItem(emoji: "🖤", name: "Black Heart", aliases: [":black_heart:"], category: "Symbols"),
        EmojiItem(emoji: "🤍", name: "White Heart", aliases: [":white_heart:"], category: "Symbols"),
        EmojiItem(emoji: "⚠️", name: "Warning", aliases: [":warning:", ":alert:", ":caution:"], category: "Symbols"),
        EmojiItem(emoji: "⛔", name: "No Entry", aliases: [":no_entry:", ":forbidden:"], category: "Symbols"),
        EmojiItem(emoji: "🛑", name: "Stop Sign", aliases: [":stop_sign:", ":stop:"], category: "Symbols"),
        EmojiItem(emoji: "🔔", name: "Bell", aliases: [":bell:", ":notification:"], category: "Symbols"),
        EmojiItem(emoji: "🔕", name: "Bell with Slash", aliases: [":mute:", ":silent_bell:"], category: "Symbols"),
        EmojiItem(emoji: "💬", name: "Speech Balloon", aliases: [":chat:", ":comment:", ":talk:"], category: "Symbols"),
        EmojiItem(emoji: "💭", name: "Thought Balloon", aliases: [":thought:", ":dream:"], category: "Symbols"),
        EmojiItem(emoji: "❓", name: "Red Question Mark", aliases: [":question:", ":help:"], category: "Symbols"),
        EmojiItem(emoji: "❗", name: "Red Exclamation Mark", aliases: [":exclamation:", ":important:"], category: "Symbols"),
        EmojiItem(emoji: "➕", name: "Plus", aliases: [":plus:", ":add:"], category: "Symbols"),
        EmojiItem(emoji: "➖", name: "Minus", aliases: [":minus:", ":subtract:"], category: "Symbols"),
        EmojiItem(emoji: "➡️", name: "Right Arrow", aliases: [":arrow_right:", ":next:"], category: "Symbols"),
        EmojiItem(emoji: "⬅️", name: "Left Arrow", aliases: [":arrow_left:", ":prev:"], category: "Symbols"),
        EmojiItem(emoji: "⬆️", name: "Up Arrow", aliases: [":arrow_up:"], category: "Symbols"),
        EmojiItem(emoji: "⬇️", name: "Down Arrow", aliases: [":arrow_down:"], category: "Symbols")
    ]

    /// Inverted dictionary for sub-millisecond lookup from alias to emoji.
    private static let lookupTable: [String: String] = {
        var table: [String: String] = [:]
        for item in all {
            for alias in item.aliases {
                table[alias.lowercased()] = item.emoji
            }
        }
        return table
    }()

    /// Strips variation selectors (\u{FE0F}) and whitespace to normalize comparison across apps.
    public static func normalizeEmoji(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{FE0F}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Matches the end of a typed keystroke buffer against all known emoji aliases.
    public static func findMatch(in buffer: String) -> Match? {
        guard buffer.hasSuffix(":") && buffer.count >= 3 else { return nil }

        let maxSearchLength = min(buffer.count, 32)
        let searchSlice = buffer.suffix(maxSearchLength)

        for (alias, emoji) in lookupTable {
            if searchSlice.hasSuffix(alias) {
                return Match(emoji: emoji, alias: alias)
            }
        }
        return nil
    }

    /// Reverse-engineers any emoji (whether in curated catalog or pasted from WhatsApp/web).
    public static func reverseEngineer(input: String) -> EmojiItem? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedInput = normalizeEmoji(trimmed)

        // 1. Direct match in curated catalog
        if let direct = all.first(where: {
            $0.emoji == trimmed || normalizeEmoji($0.emoji) == normalizedInput
        }) {
            return direct
        }

        // 2. Check if the string contains emoji scalars (e.g. from WhatsApp or latest Unicode release)
        let hasEmojiScalar = trimmed.unicodeScalars.contains { $0.properties.isEmoji || $0.properties.isEmojiPresentation }
        if hasEmojiScalar {
            let hex = trimmed.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
            let firstScalar = trimmed.unicodeScalars.first?.value ?? 0
            let autoAlias = ":emoji_\(String(format: "%x", firstScalar)):"
            return EmojiItem(
                emoji: trimmed,
                name: "Pasted Emoji (\(hex))",
                aliases: [autoAlias],
                category: "Custom"
            )
        }

        return nil
    }

    /// Filters and ranks emojis by query and optional category.
    /// Handles name search, alias search, and reverse-engineer lookup (pasting a raw emoji).
    public static func filter(query: String, category: String? = nil) -> [EmojiItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseItems: [EmojiItem]
        if let cat = category, !cat.isEmpty && cat != "All" {
            baseItems = all.filter { $0.category.localizedCaseInsensitiveCompare(cat) == .orderedSame }
        } else {
            baseItems = all
        }

        guard !trimmed.isEmpty else { return baseItems }

        let cleanQuery = trimmed.lowercased().replacingOccurrences(of: ":", with: "")

        // 1. Direct Emoji Paste Match / Reverse Engineer (e.g. user pasted "🌹" or "🔥" or an uncatalogued emoji)
        if let direct = reverseEngineer(input: trimmed) {
            let others = baseItems.filter { $0.id != direct.id && ($0.name.localizedCaseInsensitiveContains(cleanQuery) || $0.aliases.contains(where: { $0.localizedCaseInsensitiveContains(cleanQuery) })) }
            return [direct] + others
        }

        // 2. Exact alias match (e.g. "rose" matches ":rose:")
        let exactAliasMatches = baseItems.filter { item in
            item.aliases.contains { alias in
                let stripped = alias.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                return stripped.localizedCaseInsensitiveCompare(cleanQuery) == .orderedSame
            }
        }

        // 3. Name exact match
        let exactNameMatches = baseItems.filter { item in
            !exactAliasMatches.contains(where: { $0.id == item.id }) &&
            item.name.localizedCaseInsensitiveCompare(cleanQuery) == .orderedSame
        }

        // 4. Name prefix or alias prefix match
        let prefixMatches = baseItems.filter { item in
            !exactAliasMatches.contains(where: { $0.id == item.id }) &&
            !exactNameMatches.contains(where: { $0.id == item.id }) &&
            (item.name.lowercased().hasPrefix(cleanQuery) || item.aliases.contains { $0.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased().hasPrefix(cleanQuery) })
        }

        // 5. Partial contains match
        let partialMatches = baseItems.filter { item in
            !exactAliasMatches.contains(where: { $0.id == item.id }) &&
            !exactNameMatches.contains(where: { $0.id == item.id }) &&
            !prefixMatches.contains(where: { $0.id == item.id }) &&
            (item.name.localizedCaseInsensitiveContains(cleanQuery) ||
             item.aliases.contains { $0.localizedCaseInsensitiveContains(cleanQuery) })
        }

        return exactAliasMatches + exactNameMatches + prefixMatches + partialMatches
    }
}
