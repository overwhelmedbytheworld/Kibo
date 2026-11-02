import Foundation

/// Represents a single emoji and its trigger aliases.
public struct EmojiItem: Sendable, Equatable, Hashable {
    public let emoji: String
    public let name: String
    public let aliases: [String]
    public let category: String

    public init(emoji: String, name: String, aliases: [String], category: String = "Smileys") {
        self.emoji = emoji
        self.name = name
        self.aliases = aliases
        self.category = category
    }
}

/// Comprehensive catalog of macOS and Unicode emojis with multi-alias support.
public enum EmojiCatalog {
    public struct Match: Sendable, Equatable {
        public let emoji: String
        public let alias: String
    }

    /// Master list of emojis with expressive synonyms.
    public static let all: [EmojiItem] = [
        // MARK: - Expressions & Faces
        EmojiItem(emoji: "🔥", name: "Fire", aliases: [":fire:", ":flame:", ":lit:", ":hot:"], category: "Popular"),
        EmojiItem(emoji: "❤️", name: "Red Heart", aliases: [":heart:", ":love:", ":red_heart:", ":redheart:"], category: "Popular"),
        EmojiItem(emoji: "❤️‍🔥", name: "Heart on Fire", aliases: [":heart_on_fire:", ":heartonfire:", ":fire_heart:"], category: "Popular"),
        EmojiItem(emoji: "✨", name: "Sparkles", aliases: [":sparkles:", ":sparkle:", ":magic:", ":shiny:"], category: "Popular"),
        EmojiItem(emoji: "👍", name: "Thumbs Up", aliases: [":thumbsup:", ":thumbs_up:", ":+1:", ":yes:", ":like:", ":approve:"], category: "Popular"),
        EmojiItem(emoji: "👎", name: "Thumbs Down", aliases: [":thumbsdown:", ":thumbs_down:", ":-1:", ":no:", ":dislike:"], category: "Popular"),
        EmojiItem(emoji: "😂", name: "Face with Tears of Joy", aliases: [":joy:", ":laugh:", ":laughing:", ":lol:", ":lmao:"], category: "Popular"),
        EmojiItem(emoji: "🤣", name: "Rolling on the Floor Laughing", aliases: [":rofl:", ":rolling_laugh:", ":crying_laughing:"], category: "Popular"),
        EmojiItem(emoji: "😊", name: "Smiling Face", aliases: [":smile:", ":smiling:", ":happy:", ":blush:"], category: "Smileys"),
        EmojiItem(emoji: "🥰", name: "Smiling Face with Hearts", aliases: [":smiling_face_with_hearts:", ":in_love:", ":hearts_smile:"], category: "Smileys"),
        EmojiItem(emoji: "😍", name: "Heart Eyes", aliases: [":heart_eyes:", ":hearteyes:", ":love_eyes:"], category: "Smileys"),
        EmojiItem(emoji: "🤩", name: "Star-Struck", aliases: [":star_struck:", ":starstruck:", ":excited:"], category: "Smileys"),
        EmojiItem(emoji: "😘", name: "Blowing a Kiss", aliases: [":kiss:", ":kissing_heart:", ":blow_kiss:"], category: "Smileys"),
        EmojiItem(emoji: "😉", name: "Winking Face", aliases: [":wink:", ":winking:"], category: "Smileys"),
        EmojiItem(emoji: "🙃", name: "Upside-Down Face", aliases: [":upside_down:", ":upsidedown:", ":silly:"], category: "Smileys"),
        EmojiItem(emoji: "🫠", name: "Melting Face", aliases: [":melting:", ":melting_face:", ":melt:"], category: "Smileys"),
        EmojiItem(emoji: "🫡", name: "Saluting Face", aliases: [":salute:", ":saluting:", ":saluting_face:", ":respect:"], category: "Smileys"),
        EmojiItem(emoji: "😎", name: "Cool", aliases: [":cool:", ":sunglasses:", ":shades:"], category: "Smileys"),
        EmojiItem(emoji: "🤓", name: "Nerd Face", aliases: [":nerd:", ":nerd_face:", ":geek:"], category: "Smileys"),
        EmojiItem(emoji: "🧐", name: "Monocle", aliases: [":monocle:", ":curious:", ":inspect:"], category: "Smileys"),
        EmojiItem(emoji: "🤔", name: "Thinking Face", aliases: [":thinking:", ":think:", ":hmm:", ":wonder:"], category: "Smileys"),
        EmojiItem(emoji: "🤫", name: "Shushing Face", aliases: [":shush:", ":quiet:", ":secret:"], category: "Smileys"),
        EmojiItem(emoji: "🫢", name: "Face with Open Eyes and Hand Over Mouth", aliases: [":gasp:", ":shock:", ":oops:"], category: "Smileys"),
        EmojiItem(emoji: "🤗", name: "Hugging Face", aliases: [":hug:", ":hugging:", ":warmth:"], category: "Smileys"),
        EmojiItem(emoji: "😏", name: "Smirking Face", aliases: [":smirk:", ":smirking:"], category: "Smileys"),
        EmojiItem(emoji: "😬", name: "Grimacing Face", aliases: [":grimace:", ":grimacing:", ":yikes:"], category: "Smileys"),
        EmojiItem(emoji: "🥺", name: "Pleading Face", aliases: [":pleading:", ":puppy_eyes:", ":please:", ":beg:"], category: "Smileys"),
        EmojiItem(emoji: "😭", name: "Loudly Crying Face", aliases: [":sob:", ":cry:", ":crying:", ":sad:"], category: "Smileys"),
        EmojiItem(emoji: "😱", name: "Face Screaming in Fear", aliases: [":scream:", ":screaming:", ":omg:"], category: "Smileys"),
        EmojiItem(emoji: "🤯", name: "Exploding Head", aliases: [":mind_blown:", ":mindblown:", ":exploding_head:", ":shocked:"], category: "Smileys"),
        EmojiItem(emoji: "🥳", name: "Partying Face", aliases: [":party_face:", ":partying:", ":celebrating:"], category: "Smileys"),
        EmojiItem(emoji: "😴", name: "Sleeping Face", aliases: [":sleep:", ":sleeping:", ":zzz:", ":tired:"], category: "Smileys"),
        EmojiItem(emoji: "🤤", name: "Drooling Face", aliases: [":drool:", ":drooling:"], category: "Smileys"),
        EmojiItem(emoji: "🤮", name: "Vomiting Face", aliases: [":vomit:", ":puke:", ":sick:"], category: "Smileys"),
        EmojiItem(emoji: "🤧", name: "Sneezing Face", aliases: [":sneeze:", ":sneezing:", ":achoo:"], category: "Smileys"),
        EmojiItem(emoji: "🥵", name: "Hot Face", aliases: [":hot_face:", ":overheated:", ":sweating:"], category: "Smileys"),
        EmojiItem(emoji: "🥶", name: "Cold Face", aliases: [":cold_face:", ":freezing:", ":ice_cold:"], category: "Smileys"),
        EmojiItem(emoji: "😡", name: "Enraged Face", aliases: [":rage:", ":angry:", ":mad:"], category: "Smileys"),
        EmojiItem(emoji: "💀", name: "Skull", aliases: [":skull:", ":dead:", ":skeleton:"], category: "Popular"),
        EmojiItem(emoji: "☠️", name: "Skull and Crossbones", aliases: [":skull_crossbones:", ":pirate:", ":danger:"], category: "Popular"),
        EmojiItem(emoji: "🤡", name: "Clown Face", aliases: [":clown:", ":fool:"], category: "Smileys"),
        EmojiItem(emoji: "💩", name: "Pile of Poo", aliases: [":poop:", ":poo:", ":crap:"], category: "Smileys"),
        EmojiItem(emoji: "👻", name: "Ghost", aliases: [":ghost:", ":boo:", ":spooky:"], category: "Smileys"),
        EmojiItem(emoji: "👽", name: "Alien", aliases: [":alien:", ":ufo:"], category: "Smileys"),
        EmojiItem(emoji: "🤖", name: "Robot", aliases: [":robot:", ":bot:", ":ai:"], category: "Smileys"),
        EmojiItem(emoji: "🙈", name: "See-No-Evil Monkey", aliases: [":see_no_evil:", ":monkey_eyes:"], category: "Smileys"),
        EmojiItem(emoji: "🙉", name: "Hear-No-Evil Monkey", aliases: [":hear_no_evil:", ":monkey_ears:"], category: "Smileys"),
        EmojiItem(emoji: "🙊", name: "Speak-No-Evil Monkey", aliases: [":speak_no_evil:", ":monkey_mouth:"], category: "Smileys"),

        // MARK: - Hand Gestures & People
        EmojiItem(emoji: "👋", name: "Waving Hand", aliases: [":wave:", ":hi:", ":hello:", ":bye:"], category: "Gestures"),
        EmojiItem(emoji: "✋", name: "Raised Hand", aliases: [":hand:", ":stop:", ":highfive:"], category: "Gestures"),
        EmojiItem(emoji: "👌", name: "OK Hand", aliases: [":ok_hand:", ":ok:", ":perfect:"], category: "Gestures"),
        EmojiItem(emoji: "✌️", name: "Victory Hand", aliases: [":v:", ":peace:", ":victory:"], category: "Gestures"),
        EmojiItem(emoji: "🤞", name: "Crossed Fingers", aliases: [":crossed_fingers:", ":fingers_crossed:", ":luck:"], category: "Gestures"),
        EmojiItem(emoji: "🤟", name: "Love-You Gesture", aliases: [":love_you:", ":ily:"], category: "Gestures"),
        EmojiItem(emoji: "🤙", name: "Call Me Hand", aliases: [":call_me:", ":shaka:"], category: "Gestures"),
        EmojiItem(emoji: "👈", name: "Backhand Index Pointing Left", aliases: [":point_left:", ":left:"], category: "Gestures"),
        EmojiItem(emoji: "👉", name: "Backhand Index Pointing Right", aliases: [":point_right:", ":right:"], category: "Gestures"),
        EmojiItem(emoji: "👆", name: "Backhand Index Pointing Up", aliases: [":point_up:", ":up:"], category: "Gestures"),
        EmojiItem(emoji: "👇", name: "Backhand Index Pointing Down", aliases: [":point_down:", ":down:"], category: "Gestures"),
        EmojiItem(emoji: "☝️", name: "Index Pointing Up", aliases: [":one:", ":pointing_up:"], category: "Gestures"),
        EmojiItem(emoji: "👏", name: "Clapping Hands", aliases: [":clap:", ":clapping:", ":bravo:", ":applause:"], category: "Gestures"),
        EmojiItem(emoji: "🙌", name: "Raising Hands", aliases: [":raised_hands:", ":praise:", ":celebrate:"], category: "Gestures"),
        EmojiItem(emoji: "🫶", name: "Heart Hands", aliases: [":heart_hands:", ":hearthands:"], category: "Gestures"),
        EmojiItem(emoji: "🤝", name: "Handshake", aliases: [":handshake:", ":deal:", ":agreement:"], category: "Gestures"),
        EmojiItem(emoji: "🙏", name: "Folded Hands", aliases: [":pray:", ":thanks:", ":thank_you:", ":please:"], category: "Gestures"),
        EmojiItem(emoji: "💪", name: "Flexed Biceps", aliases: [":muscle:", ":strong:", ":flex:", ":power:"], category: "Gestures"),
        EmojiItem(emoji: "🧠", name: "Brain", aliases: [":brain:", ":smart:", ":mind:", ":intellect:"], category: "Gestures"),
        EmojiItem(emoji: "👀", name: "Eyes", aliases: [":eyes:", ":look:", ":see:", ":watching:"], category: "Gestures"),
        EmojiItem(emoji: "🤷", name: "Person Shrugging", aliases: [":shrug:", ":shrugging:", ":idk:"], category: "Gestures"),
        EmojiItem(emoji: "🤦", name: "Person Facepalming", aliases: [":facepalm:", ":disappointed:"], category: "Gestures"),

        // MARK: - Celebration, Symbols & Badges
        EmojiItem(emoji: "🎉", name: "Party Popper", aliases: [":tada:", ":party:", ":celebration:", ":congrats:"], category: "Celebration"),
        EmojiItem(emoji: "🎊", name: "Confetti Ball", aliases: [":confetti:", ":confetti_ball:"], category: "Celebration"),
        EmojiItem(emoji: "🎈", name: "Balloon", aliases: [":balloon:", ":birthday:"], category: "Celebration"),
        EmojiItem(emoji: "🎁", name: "Wrapped Gift", aliases: [":gift:", ":present:"], category: "Celebration"),
        EmojiItem(emoji: "🏆", name: "Trophy", aliases: [":trophy:", ":winner:", ":first:"], category: "Celebration"),
        EmojiItem(emoji: "🥇", name: "1st Place Medal", aliases: [":first_place:", ":gold_medal:", ":gold:"], category: "Celebration"),
        EmojiItem(emoji: "🥈", name: "2nd Place Medal", aliases: [":second_place:", ":silver_medal:"], category: "Celebration"),
        EmojiItem(emoji: "🥉", name: "3rd Place Medal", aliases: [":third_place:", ":bronze_medal:"], category: "Celebration"),
        EmojiItem(emoji: "⭐", name: "Star", aliases: [":star:", ":favorite:", ":fav:"], category: "Symbols"),
        EmojiItem(emoji: "🌟", name: "Glowing Star", aliases: [":glowing_star:", ":shining_star:"], category: "Symbols"),
        EmojiItem(emoji: "💯", name: "Hundred Points", aliases: [":100:", ":hundred:", ":perfect:"], category: "Symbols"),
        EmojiItem(emoji: "✅", name: "Check Mark", aliases: [":check:", ":checkmark:", ":white_check_mark:", ":done:", ":verified:"], category: "Symbols"),
        EmojiItem(emoji: "❌", name: "Cross Mark", aliases: [":cross:", ":x:", ":wrong:", ":error:", ":cancel:"], category: "Symbols"),
        EmojiItem(emoji: "⚠️", name: "Warning", aliases: [":warning:", ":warn:", ":alert:", ":caution:"], category: "Symbols"),
        EmojiItem(emoji: "🚨", name: "Police Car Light", aliases: [":siren:", ":police_light:", ":emergency:"], category: "Symbols"),
        EmojiItem(emoji: "💡", name: "Light Bulb", aliases: [":bulb:", ":idea:", ":lightbulb:"], category: "Symbols"),
        EmojiItem(emoji: "💎", name: "Gem Stone", aliases: [":gem:", ":diamond:", ":jewel:"], category: "Symbols"),
        EmojiItem(emoji: "⚡", name: "High Voltage", aliases: [":zap:", ":lightning:", ":bolt:", ":electric:"], category: "Symbols"),
        EmojiItem(emoji: "🚀", name: "Rocket", aliases: [":rocket:", ":launch:", ":speed:", ":fast:"], category: "Popular"),
        EmojiItem(emoji: "📌", name: "Pushpin", aliases: [":pin:", ":pushpin:", ":pinned:"], category: "Symbols"),
        EmojiItem(emoji: "📍", name: "Round Pushpin", aliases: [":location:", ":round_pushpin:", ":map_pin:"], category: "Symbols"),
        EmojiItem(emoji: "🔗", name: "Link", aliases: [":link:", ":chain:", ":url:"], category: "Symbols"),
        EmojiItem(emoji: "🔒", name: "Locked", aliases: [":lock:", ":locked:", ":secure:", ":private:"], category: "Symbols"),
        EmojiItem(emoji: "🔓", name: "Unlocked", aliases: [":unlock:", ":unlocked:", ":open:"], category: "Symbols"),
        EmojiItem(emoji: "🔑", name: "Key", aliases: [":key:", ":access:", ":password:"], category: "Symbols"),
        EmojiItem(emoji: "🔍", name: "Magnifying Glass Left", aliases: [":search:", ":magnifying_glass:", ":find:"], category: "Symbols"),
        EmojiItem(emoji: "⚙️", name: "Gear", aliases: [":gear:", ":settings:", ":config:", ":cog:"], category: "Symbols"),
        EmojiItem(emoji: "💰", name: "Money Bag", aliases: [":money:", ":moneybag:", ":cash:", ":rich:"], category: "Symbols"),
        EmojiItem(emoji: "💵", name: "Dollar Banknote", aliases: [":dollar:", ":bill:", ":cash_bill:"], category: "Symbols"),
        EmojiItem(emoji: "💳", name: "Credit Card", aliases: [":credit_card:", ":payment:", ":card:"], category: "Symbols"),
        EmojiItem(emoji: "⏰", name: "Alarm Clock", aliases: [":alarm:", ":alarm_clock:", ":clock:"], category: "Symbols"),
        EmojiItem(emoji: "📅", name: "Calendar", aliases: [":calendar:", ":date:", ":schedule:"], category: "Symbols"),
        EmojiItem(emoji: "✉️", name: "Envelope", aliases: [":email:", ":mail:", ":envelope:", ":letter:"], category: "Symbols"),
        EmojiItem(emoji: "📦", name: "Package", aliases: [":package:", ":box:", ":delivery:"], category: "Symbols"),
        EmojiItem(emoji: "📝", name: "Memo", aliases: [":memo:", ":note:", ":pencil_paper:"], category: "Symbols"),
        EmojiItem(emoji: "✏️", name: "Pencil", aliases: [":pencil:", ":write:", ":draft:"], category: "Symbols"),
        EmojiItem(emoji: "💻", name: "Laptop", aliases: [":laptop:", ":computer:", ":pc:", ":macbook:"], category: "Symbols"),
        EmojiItem(emoji: "📱", name: "Mobile Phone", aliases: [":phone:", ":mobile:", ":iphone:", ":cell:"], category: "Symbols"),
        EmojiItem(emoji: "👑", name: "Crown", aliases: [":crown:", ":king:", ":queen:", ":royal:"], category: "Symbols"),
        EmojiItem(emoji: "💬", name: "Speech Balloon", aliases: [":chat:", ":speech_bubble:", ":comment:"], category: "Symbols"),
        EmojiItem(emoji: "💭", name: "Thought Balloon", aliases: [":thought:", ":thought_bubble:"], category: "Symbols"),
        EmojiItem(emoji: "❓", name: "Question Mark", aliases: [":question:", ":help:", ":what:"], category: "Symbols"),
        EmojiItem(emoji: "❗", name: "Exclamation Mark", aliases: [":exclamation:", ":important:"], category: "Symbols"),
        EmojiItem(emoji: "‼️", name: "Double Exclamation Mark", aliases: [":bangbang:", ":urgent:"], category: "Symbols"),
        EmojiItem(emoji: "♾️", name: "Infinity", aliases: [":infinity:", ":forever:", ":loop:"], category: "Symbols"),

        // MARK: - Food & Drink
        EmojiItem(emoji: "☕", name: "Hot Beverage", aliases: [":coffee:", ":cafe:", ":tea_coffee:"], category: "Food"),
        EmojiItem(emoji: "🍵", name: "Teacup Without Handle", aliases: [":tea:", ":green_tea:"], category: "Food"),
        EmojiItem(emoji: "🍺", name: "Beer Mug", aliases: [":beer:", ":pint:", ":cheers:"], category: "Food"),
        EmojiItem(emoji: "🍻", name: "Clinking Beer Mugs", aliases: [":beers:", ":clinking_beer:"], category: "Food"),
        EmojiItem(emoji: "🍷", name: "Wine Glass", aliases: [":wine:", ":vino:"], category: "Food"),
        EmojiItem(emoji: "🍕", name: "Pizza", aliases: [":pizza:", ":slice:"], category: "Food"),
        EmojiItem(emoji: "🍔", name: "Hamburger", aliases: [":burger:", ":hamburger:"], category: "Food"),
        EmojiItem(emoji: "🍟", name: "French Fries", aliases: [":fries:", ":french_fries:"], category: "Food"),
        EmojiItem(emoji: "🌮", name: "Taco", aliases: [":taco:"], category: "Food"),
        EmojiItem(emoji: "🌯", name: "Burrito", aliases: [":burrito:"], category: "Food"),
        EmojiItem(emoji: "🍣", name: "Sushi", aliases: [":sushi:"], category: "Food"),
        EmojiItem(emoji: "🍿", name: "Popcorn", aliases: [":popcorn:", ":movie_snack:"], category: "Food"),
        EmojiItem(emoji: "🍩", name: "Doughnut", aliases: [":donut:", ":doughnut:"], category: "Food"),
        EmojiItem(emoji: "🍪", name: "Cookie", aliases: [":cookie:", ":biscuit:"], category: "Food"),
        EmojiItem(emoji: "🎂", name: "Birthday Cake", aliases: [":cake:", ":birthday_cake:"], category: "Food"),
        EmojiItem(emoji: "🍫", name: "Chocolate Bar", aliases: [":chocolate:", ":candy:"], category: "Food"),
        EmojiItem(emoji: "🍎", name: "Red Apple", aliases: [":apple:", ":red_apple:"], category: "Food"),
        EmojiItem(emoji: "🍌", name: "Banana", aliases: [":banana:"], category: "Food"),
        EmojiItem(emoji: "🥑", name: "Avocado", aliases: [":avocado:"], category: "Food"),

        // MARK: - Animals & Nature
        EmojiItem(emoji: "🐶", name: "Dog Face", aliases: [":dog:", ":puppy:", ":york:", ":yorkie:"], category: "Animals"),
        EmojiItem(emoji: "🐱", name: "Cat Face", aliases: [":cat:", ":kitty:", ":kitten:"], category: "Animals"),
        EmojiItem(emoji: "🦊", name: "Fox", aliases: [":fox:", ":fox_face:"], category: "Animals"),
        EmojiItem(emoji: "🐻", name: "Bear", aliases: [":bear:", ":grizzly:"], category: "Animals"),
        EmojiItem(emoji: "🐼", name: "Panda", aliases: [":panda:", ":panda_face:"], category: "Animals"),
        EmojiItem(emoji: "🐨", name: "Koala", aliases: [":koala:"], category: "Animals"),
        EmojiItem(emoji: "🦁", name: "Lion", aliases: [":lion:", ":king_beast:"], category: "Animals"),
        EmojiItem(emoji: "🐵", name: "Monkey Face", aliases: [":monkey:", ":chimp:"], category: "Animals"),
        EmojiItem(emoji: "🐧", name: "Penguin", aliases: [":penguin:"], category: "Animals"),
        EmojiItem(emoji: "🦅", name: "Eagle", aliases: [":eagle:"], category: "Animals"),
        EmojiItem(emoji: "🦉", name: "Owl", aliases: [":owl:"], category: "Animals"),
        EmojiItem(emoji: "🦋", name: "Butterfly", aliases: [":butterfly:"], category: "Animals"),
        EmojiItem(emoji: "🐝", name: "Honeybee", aliases: [":bee:", ":honeybee:"], category: "Animals"),
        EmojiItem(emoji: "🐍", name: "Snake", aliases: [":snake:"], category: "Animals"),
        EmojiItem(emoji: "🦈", name: "Shark", aliases: [":shark:"], category: "Animals"),
        EmojiItem(emoji: "🐬", name: "Dolphin", aliases: [":dolphin:"], category: "Animals"),
        EmojiItem(emoji: "🌺", name: "Hibiscus", aliases: [":flower:", ":hibiscus:"], category: "Animals"),
        EmojiItem(emoji: "🌸", name: "Cherry Blossom", aliases: [":cherry_blossom:", ":sakura:"], category: "Animals"),
        EmojiItem(emoji: "🌹", name: "Rose", aliases: [":rose:"], category: "Animals"),
        EmojiItem(emoji: "🌲", name: "Evergreen Tree", aliases: [":tree:", ":evergreen:"], category: "Animals"),
        EmojiItem(emoji: "🌴", name: "Palm Tree", aliases: [":palm_tree:", ":palm:"], category: "Animals"),

        // MARK: - Weather, Travel & Places
        EmojiItem(emoji: "☀️", name: "Sun", aliases: [":sun:", ":sunny:", ":warm:"], category: "Travel"),
        EmojiItem(emoji: "🌙", name: "Crescent Moon", aliases: [":moon:", ":night:"], category: "Travel"),
        EmojiItem(emoji: "⭐", name: "Star", aliases: [":star_night:"], category: "Travel"),
        EmojiItem(emoji: "☁️", name: "Cloud", aliases: [":cloud:", ":cloudy:"], category: "Travel"),
        EmojiItem(emoji: "🌧️", name: "Cloud with Rain", aliases: [":rain:", ":rainy:"], category: "Travel"),
        EmojiItem(emoji: "❄️", name: "Snowflake", aliases: [":snow:", ":snowflake:", ":winter:"], category: "Travel"),
        EmojiItem(emoji: "🌈", name: "Rainbow", aliases: [":rainbow:"], category: "Travel"),
        EmojiItem(emoji: "🏖️", name: "Beach with Umbrella", aliases: [":beach:", ":vacation:", ":island:"], category: "Travel"),
        EmojiItem(emoji: "⛰️", name: "Mountain", aliases: [":mountain:", ":hike:"], category: "Travel"),
        EmojiItem(emoji: "🚗", name: "Automobile", aliases: [":car:", ":auto:", ":drive:"], category: "Travel"),
        EmojiItem(emoji: "✈️", name: "Airplane", aliases: [":airplane:", ":plane:", ":flight:"], category: "Travel"),
        EmojiItem(emoji: "🚢", name: "Ship", aliases: [":ship:", ":boat:", ":cruise:"], category: "Travel"),
        EmojiItem(emoji: "🚆", name: "Train", aliases: [":train:", ":metro:"], category: "Travel"),
        EmojiItem(emoji: "🏠", name: "House", aliases: [":house:", ":home:"], category: "Travel"),
        EmojiItem(emoji: "🏢", name: "Office Building", aliases: [":office:", ":workplace:"], category: "Travel"),
        EmojiItem(emoji: "🌍", name: "Globe Showing Europe-Africa", aliases: [":earth:", ":globe:", ":world:"], category: "Travel")
    ]

    /// Inverted dictionary for sub-millisecond lookup from alias to emoji.
    public static let lookupTable: [String: String] = {
        var table: [String: String] = [:]
        for item in all {
            for alias in item.aliases {
                let clean = alias.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
                // 1. Colon-wrapped: ":fire:"
                table[":\(clean):"] = item.emoji
                // 2. Without underscore: ":thumbsup:"
                let noUnder = clean.replacingOccurrences(of: "_", with: "")
                table[":\(noUnder):"] = item.emoji
                // 3. With hyphens: ":thumbs-up:"
                let hyphenated = clean.replacingOccurrences(of: "_", with: "-")
                table[":\(hyphenated):"] = item.emoji
            }
        }
        return table
    }()

    /// Matches the end of a typed keystroke buffer against all known emoji aliases.
    public static func findMatch(in buffer: String) -> Match? {
        guard buffer.hasSuffix(":") && buffer.count >= 3 else { return nil }

        // Inspect suffixes up to 32 characters
        let maxSearchLength = min(buffer.count, 32)
        let searchSlice = buffer.suffix(maxSearchLength)

        for (alias, emoji) in lookupTable {
            if searchSlice.hasSuffix(alias) {
                return Match(emoji: emoji, alias: alias)
            }
        }
        return nil
    }

    /// Filters emojis by query for search panels.
    public static func filter(query: String) -> [EmojiItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }
        let cleanQuery = trimmed.replacingOccurrences(of: ":", with: "")

        return all.filter { item in
            item.name.lowercased().contains(cleanQuery) ||
            item.aliases.contains(where: { $0.lowercased().contains(cleanQuery) }) ||
            item.emoji == trimmed
        }
    }
}
