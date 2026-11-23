// File: Core/Learn/LearnContent+Markets.swift
// Learn content: the Crypto basics and Forex basics tracks.

import Foundation

extension LearnContent {

    // MARK: - Crypto basics

    static let cryptoTrack = LearnTrack(
        id: "crypto",
        title: "Crypto basics",
        subtitle: "Exchanges, wallets, volatility and stablecoins",
        systemImage: "bitcoinsign.circle.fill",
        tint: .orange,
        lessons: [
            LearnLesson(
                id: "crypto-what-is-crypto",
                title: "What crypto is",
                summary: "Blockchains, coins and tokens in plain words",
                minutes: 2,
                blocks: [
                    .paragraph("A cryptocurrency is a digital asset that lives on a shared record called a blockchain. There is no bank in the middle. Instead, a network of computers agrees on who owns what."),
                    .heading("What a blockchain does"),
                    .paragraph("Think of a blockchain as a public ledger that many computers keep a copy of. New transactions are grouped into blocks. Once a block is added, changing it is extremely hard, because the network would have to agree to rewrite history."),
                    .bullets([
                        "Anyone can usually view the transactions on a public blockchain.",
                        "Ownership is tied to digital keys, not to your name or ID.",
                        "Transactions are generally final. There is often no way to reverse a mistake."
                    ]),
                    .heading("Coins and tokens"),
                    .paragraph("People use these words loosely, but there is a useful difference."),
                    .bullets([
                        "A coin is native to its own blockchain, like bitcoin on the Bitcoin network or ether on Ethereum.",
                        "A token is built on top of an existing blockchain. Many tokens run on Ethereum, for example.",
                        "Anyone can create a token, so a new token tells you nothing about its quality."
                    ]),
                    .heading("Why prices move"),
                    .paragraph("Most crypto assets have no earnings or cash flow to value them by. Prices are driven mostly by supply, demand, news and sentiment. That is one reason crypto can swing much more than large company stocks."),
                    .tip("Being able to see a project's code or transactions does not mean it is safe. Plenty of tokens have gone to zero.")
                ],
                takeaways: [
                    "A blockchain is a shared ledger kept by many computers.",
                    "Coins are native to a blockchain; tokens are built on top of one.",
                    "Crypto transactions are usually final, so mistakes are hard to undo.",
                    "Prices are driven mostly by demand and sentiment, not earnings."
                ]
            ),
            LearnLesson(
                id: "crypto-exchanges",
                title: "Exchanges",
                summary: "Where crypto is bought and sold, and the risks",
                minutes: 3,
                blocks: [
                    .paragraph("An exchange is where you buy and sell crypto. Choosing one is a real decision, because the exchange may hold your money and your coins."),
                    .heading("Centralized exchanges"),
                    .paragraph("A centralized exchange is a company. You create an account, verify your identity, deposit money and trade on its platform. It is usually the easiest place to start."),
                    .bullets([
                        "The exchange holds your assets on your behalf.",
                        "It can freeze accounts, pause withdrawals or go out of business.",
                        "Rules and protections depend on the country it is licensed in."
                    ]),
                    .heading("Decentralized exchanges"),
                    .paragraph("A decentralized exchange, or DEX, is software running on a blockchain. You trade straight from your own wallet, with no company holding your funds. The trade-off is that you are fully responsible for every step, and fake tokens and buggy code are common."),
                    .heading("Fees and counterparty risk"),
                    .paragraph("Fees add up. Look for trading fees, the spread between buy and sell prices, and withdrawal fees. Network fees on a DEX can also be high when the blockchain is busy."),
                    .paragraph("Counterparty risk is the risk that the other side fails you. Several large exchanges have collapsed, and customers lost access to their funds. Crypto held on an exchange is generally not covered by deposit insurance the way a bank account is."),
                    .tip("Only keep on an exchange what you are actively trading. Check how the exchange is regulated where you live before you deposit.")
                ],
                takeaways: [
                    "Centralized exchanges are easy to use but hold your assets for you.",
                    "Decentralized exchanges let you trade from your own wallet, with more responsibility.",
                    "Count all the fees: trading, spread, withdrawal and network fees.",
                    "Crypto on an exchange usually has no deposit insurance like a bank."
                ]
            ),
            LearnLesson(
                id: "crypto-wallets",
                title: "Wallets",
                summary: "Custody, seed phrases, hot and cold storage",
                minutes: 3,
                blocks: [
                    .paragraph("A crypto wallet does not really store coins. It stores the keys that prove you own them on the blockchain. Whoever controls the keys controls the funds."),
                    .heading("Custodial or self-custody"),
                    .bullets([
                        "Custodial: a company, such as an exchange, holds the keys for you. It is convenient, and you can usually reset a forgotten password, but you rely on that company.",
                        "Self-custody: you hold the keys yourself. No company can freeze your funds, but no one can recover them for you either."
                    ]),
                    .heading("Seed phrases"),
                    .paragraph("When you set up a self-custody wallet, it gives you a seed phrase, usually 12 or 24 words. Those words can rebuild your wallet on any device. Anyone who has them can take everything in it."),
                    .bullets([
                        "Write the phrase down on paper and store it somewhere safe and private.",
                        "Never type it into a website, chat or form.",
                        "Never share it with anyone, including support staff, community leaders or friends."
                    ]),
                    .tip("No real exchange or wallet maker will ever ask for your seed phrase, and no one in an Arkad community should. Anyone who asks is trying to steal from you."),
                    .heading("Hot and cold wallets"),
                    .paragraph("A hot wallet is connected to the internet, like a phone app or browser extension. It is handy for small, frequent use. A cold wallet keeps the keys offline, often on a small hardware device. It is slower to use but much harder to hack."),
                    .paragraph("Many people keep a small amount in a hot wallet for daily use and the rest in cold storage.")
                ],
                takeaways: [
                    "A wallet holds the keys that control your crypto.",
                    "Custodial is convenient; self-custody puts you fully in charge.",
                    "Your seed phrase is your money. Never share it with anyone.",
                    "Hot wallets are convenient; cold wallets are safer for larger amounts."
                ]
            ),
            LearnLesson(
                id: "crypto-volatility",
                title: "Volatility and 24/7 markets",
                summary: "Big swings, weekend moves and thin liquidity",
                minutes: 3,
                blocks: [
                    .paragraph("Crypto markets never close. They trade every hour of every day, including weekends and holidays. Combined with large price swings, that changes how you need to manage risk."),
                    .heading("Bigger swings"),
                    .paragraph("Moves of 5 to 10 percent in a day are common for major coins, and smaller coins can move far more. A position that would be sensible in a large stock can be too big in crypto."),
                    .example(title: "Same risk, smaller size", lines: [
                        "You are willing to lose $100 on a trade.",
                        "On a stock you might place a stop 5% below entry: $100 / 5% = $2,000 position.",
                        "On a coin that swings more, you need a stop 12% away: $100 / 12% = about $833 position.",
                        "Wider stop, smaller position, same dollar risk."
                    ]),
                    .heading("Weekend and overnight moves"),
                    .bullets([
                        "Prices can move sharply while you sleep or on a Sunday.",
                        "News can hit at any hour, and there is no closing bell to pause things.",
                        "Stop orders can fill well past your price in a fast move."
                    ]),
                    .heading("Liquidity in small coins"),
                    .paragraph("Liquidity is how easily you can buy or sell without moving the price. Small coins often have few buyers and sellers. Spreads are wide, and a single large order can push the price a lot. Getting out can be much harder than getting in."),
                    .tip("If a coin trades very little volume, assume you may not be able to sell it at the price on your screen.")
                ],
                takeaways: [
                    "Crypto trades 24/7, so prices can move while you are away.",
                    "Larger swings call for smaller positions to keep the same risk.",
                    "Stops can fill past your price in fast markets.",
                    "Small coins can be hard to sell without moving the price."
                ]
            ),
            LearnLesson(
                id: "crypto-stablecoins",
                title: "Stablecoins",
                summary: "Tokens pegged to a currency, and how pegs break",
                minutes: 2,
                blocks: [
                    .paragraph("A stablecoin is a token designed to hold a steady value, usually one US dollar. Traders use stablecoins to move between coins, park money between trades, or send value across exchanges."),
                    .heading("How a peg is kept"),
                    .bullets([
                        "Reserve-backed: a company holds cash and short-term bonds and promises to redeem each token for one dollar.",
                        "Crypto-backed: the token is backed by more crypto than it is worth, held in on-chain contracts.",
                        "Algorithmic: code tries to hold the price by adjusting supply. Several of these have failed badly."
                    ]),
                    .heading("Depeg risk"),
                    .paragraph("A stablecoin can lose its peg. If people doubt the reserves, or the mechanism breaks, the price can drop below one dollar, sometimes quickly. Some stablecoins have fallen close to zero."),
                    .paragraph("Before you rely on one, ask what backs it, who holds the reserves, and whether those reserves are checked by an outside firm."),
                    .heading("Not a bank deposit"),
                    .paragraph("A stablecoin is not the same as dollars in a bank account. It is a claim on the issuer, not a government-insured deposit. If the issuer or the exchange holding it fails, you may lose some or all of it."),
                    .tip("Treat a stablecoin balance as a crypto asset with its own risks, not as cash.")
                ],
                takeaways: [
                    "Stablecoins aim to stay at a fixed value, usually one dollar.",
                    "Pegs are held by reserves, crypto collateral or code.",
                    "Any stablecoin can lose its peg, and some have collapsed.",
                    "A stablecoin is not an insured bank deposit."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "crypto-q1",
                prompt: "Someone in a chat says they are from support and asks for your seed phrase to fix your wallet. What should you do?",
                options: [
                    "Share it, since support needs it to help",
                    "Share only the first half of the words",
                    "Refuse. Anyone who asks for it is trying to steal from you"
                ],
                answerIndex: 2,
                explanation: "Your seed phrase gives full control of your wallet. No legitimate company or person will ever ask for it."
            ),
            LearnQuizQuestion(
                id: "crypto-q2",
                prompt: "What is the main risk of keeping crypto on a centralized exchange?",
                options: [
                    "The exchange could fail or freeze withdrawals",
                    "Your coins earn too little interest",
                    "Prices on exchanges never change",
                    "You cannot see your balance"
                ],
                answerIndex: 0,
                explanation: "The exchange holds your assets for you. If it collapses or freezes withdrawals, you may lose access, and there is usually no deposit insurance."
            ),
            LearnQuizQuestion(
                id: "crypto-q3",
                prompt: "You usually risk $100 per trade. A coin needs a stop twice as far away as your usual trades. What should you do with position size?",
                options: [
                    "Keep the same position size",
                    "Make the position smaller",
                    "Make the position larger"
                ],
                answerIndex: 1,
                explanation: "A wider stop means each unit can lose more. Shrinking the position keeps your dollar risk the same."
            ),
            LearnQuizQuestion(
                id: "crypto-q4",
                prompt: "Which statement about stablecoins is true?",
                options: [
                    "They are insured like bank deposits",
                    "They can never fall below one dollar",
                    "They are issued by central banks",
                    "They can lose their peg if confidence or the mechanism fails"
                ],
                answerIndex: 3,
                explanation: "Stablecoins aim for a fixed value but can depeg. They are claims on an issuer, not insured deposits."
            )
        ]
    )

    // MARK: - Forex basics

    static let forexTrack = LearnTrack(
        id: "forex",
        title: "Forex basics",
        subtitle: "Pairs, pips, lots, leverage and sessions",
        systemImage: "dollarsign.arrow.circlepath",
        tint: .green,
        lessons: [
            LearnLesson(
                id: "forex-currency-pairs",
                title: "Currency pairs",
                summary: "Base and quote currencies, and how to read a price",
                minutes: 2,
                blocks: [
                    .paragraph("In forex you always trade one currency against another. That is why prices come in pairs, like EUR/USD. Buying the pair means buying the first currency and selling the second at the same time."),
                    .heading("Base and quote"),
                    .bullets([
                        "The first currency is the base. In EUR/USD it is the euro.",
                        "The second currency is the quote. In EUR/USD it is the US dollar.",
                        "The price tells you how much of the quote currency buys one unit of the base."
                    ]),
                    .example(title: "Reading EUR/USD 1.0850", lines: [
                        "1 euro costs 1.0850 US dollars.",
                        "If the price rises to 1.0900, the euro has strengthened against the dollar.",
                        "If it falls to 1.0800, the euro has weakened against the dollar."
                    ]),
                    .heading("Majors and minors"),
                    .paragraph("Major pairs include the US dollar and another large currency, such as EUR/USD, USD/JPY, GBP/USD and USD/CHF. They trade the most, so spreads are usually tight."),
                    .paragraph("Minor pairs, also called crosses, leave out the US dollar, like EUR/GBP or AUD/JPY. Exotic pairs combine a major currency with a smaller one. They often have wider spreads and sharper moves."),
                    .tip("Start with one or two major pairs. Learning how a single pair behaves is more useful than watching ten.")
                ],
                takeaways: [
                    "Forex prices show one currency against another.",
                    "The base comes first; the price is how much quote currency buys one base unit.",
                    "Majors include the US dollar and usually have the tightest spreads.",
                    "Minors and exotics can be more expensive and more volatile to trade."
                ]
            ),
            LearnLesson(
                id: "forex-pips",
                title: "Pips",
                summary: "How forex moves are measured, with a worked example",
                minutes: 3,
                blocks: [
                    .paragraph("Currency prices move in tiny steps, so traders measure them in pips. A pip is the standard unit for a price change in a pair."),
                    .heading("Where the pip is"),
                    .bullets([
                        "For most pairs, a pip is the fourth decimal place: 0.0001.",
                        "For pairs quoted in Japanese yen, a pip is the second decimal place: 0.01.",
                        "Many platforms show one more digit. That smaller step is a fractional pip, sometimes called a pipette."
                    ]),
                    .example(title: "Counting pips", lines: [
                        "EUR/USD moves from 1.0850 to 1.0875.",
                        "1.0875 - 1.0850 = 0.0025, which is 25 pips.",
                        "USD/JPY moves from 150.20 to 150.65.",
                        "150.65 - 150.20 = 0.45, which is 45 pips."
                    ]),
                    .heading("What a pip is worth"),
                    .paragraph("The dollar value of a pip depends on how much you trade. Multiply the number of units by the pip size."),
                    .example(title: "Pip value on EUR/USD", lines: [
                        "Standard lot: 100,000 euros.",
                        "Pip size: 0.0001.",
                        "100,000 x 0.0001 = $10 per pip.",
                        "A 25 pip move is about 25 x $10 = $250, gain or loss."
                    ]),
                    .paragraph("For pairs where the US dollar is not the quote currency, the pip value changes a little with the exchange rate. Most platforms calculate it for you."),
                    .tip("Before entering a trade, work out how many pips away your stop is and what that costs in dollars.")
                ],
                takeaways: [
                    "A pip is usually 0.0001, or 0.01 for yen pairs.",
                    "Pip value depends on your trade size.",
                    "On a standard lot of EUR/USD, one pip is about $10.",
                    "Always translate your stop distance from pips into dollars."
                ]
            ),
            LearnLesson(
                id: "forex-lots",
                title: "Lots",
                summary: "Standard, mini and micro trade sizes",
                minutes: 2,
                blocks: [
                    .paragraph("Forex trade sizes are measured in lots. A lot is a set number of units of the base currency. Knowing the sizes helps you control how much each pip is worth."),
                    .heading("The common sizes"),
                    .bullets([
                        "Standard lot: 100,000 units. About $10 per pip on EUR/USD.",
                        "Mini lot: 10,000 units. About $1 per pip on EUR/USD.",
                        "Micro lot: 1,000 units. About $0.10 per pip on EUR/USD."
                    ]),
                    .paragraph("Many brokers let you trade in fractions of a lot, like 0.05 lots, which is 5,000 units."),
                    .heading("Choosing a size"),
                    .paragraph("Pick your size from your risk, not from how confident you feel. Decide how much you can lose, find your stop distance in pips, then solve for the size."),
                    .example(title: "Sizing a trade", lines: [
                        "Account: $5,000. Risk 1%: $50.",
                        "Stop distance: 25 pips.",
                        "$50 / 25 pips = $2 per pip.",
                        "$2 per pip on EUR/USD is about 2 mini lots, or 20,000 units."
                    ]),
                    .tip("Micro lots are a good way to practice with real money while keeping each pip worth only cents.")
                ],
                takeaways: [
                    "A standard lot is 100,000 units, a mini 10,000 and a micro 1,000.",
                    "Lot size sets how much each pip is worth.",
                    "Choose size from your risk and stop distance, not from confidence.",
                    "Smaller lots let you learn with less at stake."
                ]
            ),
            LearnLesson(
                id: "forex-leverage",
                title: "Leverage and margin",
                summary: "Why small moves can mean big gains or losses",
                minutes: 3,
                blocks: [
                    .paragraph("Leverage lets you control a large position with a smaller deposit. Forex brokers offer a lot of it, which is why it deserves careful attention."),
                    .heading("How it works"),
                    .paragraph("The deposit you put up is called margin. With 50:1 leverage, every $1 of margin controls $50 of currency."),
                    .example(title: "50:1 leverage", lines: [
                        "You open a $100,000 position on EUR/USD.",
                        "At 50:1, the margin required is $100,000 / 50 = $2,000.",
                        "Price moves 1% against you: the loss is $1,000.",
                        "That is half of your $2,000 margin, from a 1% move."
                    ]),
                    .paragraph("Leverage magnifies losses exactly as much as gains. The currency moved only 1%, but the money at stake moved 50%."),
                    .heading("Margin calls"),
                    .bullets([
                        "If losses eat into your margin, the broker may ask you to add funds. This is a margin call.",
                        "If you do not, or the drop is fast, the broker can close your position automatically.",
                        "In sharp moves you can lose more than you planned, and with some brokers more than your deposit."
                    ]),
                    .heading("Limits for retail traders"),
                    .paragraph("Many regulators cap the leverage offered to everyday traders. In the US, the limit on major pairs is 50:1. In the UK and EU it is 30:1. Brokers offering much higher leverage are often based where rules are looser."),
                    .tip("You do not have to use all the leverage offered. Size from your risk, and leverage becomes a detail.")
                ],
                takeaways: [
                    "Margin is the deposit; leverage is how much it controls.",
                    "Leverage magnifies losses as much as gains.",
                    "Margin calls and forced closes can happen fast.",
                    "Regulators limit retail leverage; very high offers are a warning sign."
                ]
            ),
            LearnLesson(
                id: "forex-sessions",
                title: "Trading sessions",
                summary: "When the forex market is busy, quiet or closed",
                minutes: 2,
                blocks: [
                    .paragraph("The forex market runs 24 hours a day, five days a week. It follows the business day around the world, passing from one financial center to the next."),
                    .heading("The four main sessions"),
                    .paragraph("Times below are approximate, in US Eastern time, and shift with daylight saving."),
                    .bullets([
                        "Sydney: about 5 p.m. to 2 a.m. The week opens here on Sunday evening.",
                        "Tokyo: about 7 p.m. to 4 a.m. Yen pairs are often more active.",
                        "London: about 3 a.m. to 12 p.m. The busiest single session.",
                        "New York: about 8 a.m. to 5 p.m. US economic news lands here."
                    ]),
                    .heading("Overlaps"),
                    .paragraph("When two sessions are open at once, trading volume rises. The London and New York overlap, roughly 8 a.m. to 12 p.m. Eastern, is usually the most active time for major pairs. Spreads tend to be tighter and moves larger."),
                    .paragraph("Late in the New York afternoon and before Tokyo opens, the market is often quiet, with wider spreads."),
                    .heading("Weekend gaps"),
                    .paragraph("The market closes on Friday afternoon in New York and reopens on Sunday evening. News over the weekend can make the price open far from where it closed. That jump is a gap, and a stop order may fill at the new price, not at your stop.")
                ],
                takeaways: [
                    "Forex trades 24 hours a day, five days a week.",
                    "Sydney, Tokyo, London and New York each bring their own activity.",
                    "The London and New York overlap is usually the busiest time.",
                    "Weekend gaps can make stops fill past your price."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "forex-q1",
                prompt: "EUR/USD is quoted at 1.0850. What does that mean?",
                options: [
                    "1 US dollar costs 1.0850 euros",
                    "1 euro costs 1.0850 US dollars",
                    "The euro rose 1.085% today"
                ],
                answerIndex: 1,
                explanation: "The euro is the base currency. The price is how many US dollars buy one euro."
            ),
            LearnQuizQuestion(
                id: "forex-q2",
                prompt: "On a standard lot of EUR/USD, about how much is one pip worth?",
                options: [
                    "$0.10",
                    "$1",
                    "$10",
                    "$100"
                ],
                answerIndex: 2,
                explanation: "A standard lot is 100,000 units. 100,000 x 0.0001 = $10 per pip."
            ),
            LearnQuizQuestion(
                id: "forex-q3",
                prompt: "With 50:1 leverage, a $100,000 position moves 1% against you. How much of your $2,000 margin is lost?",
                options: [
                    "Half of it, $1,000",
                    "1% of it, $20",
                    "None, leverage protects you",
                    "All of it, $2,000"
                ],
                answerIndex: 0,
                explanation: "1% of $100,000 is $1,000, which is half of the $2,000 margin. Leverage magnifies losses."
            ),
            LearnQuizQuestion(
                id: "forex-q4",
                prompt: "When is the forex market usually most active for major pairs?",
                options: [
                    "Saturday afternoon",
                    "Late in the New York afternoon",
                    "Before the Sydney open",
                    "During the London and New York overlap"
                ],
                answerIndex: 3,
                explanation: "When London and New York are both open, volume is highest and spreads are usually tightest."
            )
        ]
    )
}
