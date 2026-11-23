// File: Core/Learn/LearnContent+Basics.swift
// Learn content: the Trading basics and Risk management tracks.

import Foundation

extension LearnContent {

    // MARK: - Trading basics

    static let basicsTrack = LearnTrack(
        id: "basics",
        title: "Trading basics",
        subtitle: "Markets, orders, prices and brokers",
        systemImage: "graduationcap.fill",
        tint: .gold,
        lessons: [
            LearnLesson(
                id: "basics-markets",
                title: "What a market is",
                summary: "Where buyers meet sellers, and why prices move",
                minutes: 2,
                blocks: [
                    .paragraph("A market is simply a place where buyers and sellers agree on prices. Every trade has two sides: someone buying and someone selling. The price you see is the last price two people agreed on."),
                    .heading("Why prices move"),
                    .paragraph("Prices move when one side is more eager than the other. If more people want to buy than sell at today's price, buyers have to offer more, and the price rises. If sellers are in a hurry, the price falls."),
                    .bullets([
                        "News, such as earnings reports or economic data, changes what people think something is worth.",
                        "Big buyers and sellers, like funds, can move prices with large orders.",
                        "Fear and excitement can push prices further than the news alone would suggest."
                    ]),
                    .heading("The four markets in Arkad"),
                    .bullets([
                        "Stocks: small pieces of ownership in a company, such as Apple or Ford.",
                        "Options: contracts that give the right to buy or sell a stock at a set price before a set date.",
                        "Crypto: digital assets such as Bitcoin and Ether, traded on crypto exchanges.",
                        "Forex: currencies traded in pairs, such as the euro against the US dollar."
                    ]),
                    .paragraph("Each market has its own hours, costs and risks, which later lessons and tracks cover."),
                    .tip("Nobody knows for sure where a price goes next. Trading is about managing that uncertainty, not removing it.")
                ],
                takeaways: [
                    "A price is the latest point where a buyer and a seller agreed.",
                    "Prices move when buyers or sellers are more eager than the other side.",
                    "Stocks, options, crypto and forex each work a little differently."
                ]
            ),
            LearnLesson(
                id: "basics-order-types",
                title: "Order types",
                summary: "Market, limit, stop and stop-limit orders",
                minutes: 3,
                blocks: [
                    .paragraph("An order is your instruction to the broker: what to buy or sell, how much, and on what terms. Choosing the right order type helps you control the price you get."),
                    .heading("Market orders"),
                    .paragraph("A market order buys or sells right away at the best price available. It almost always fills, but you don't control the exact price. In a fast or thinly traded market, the fill can be worse than the price you saw on screen."),
                    .heading("Limit orders"),
                    .paragraph("A limit order sets the worst price you'll accept. A buy limit fills at your price or lower. A sell limit fills at your price or higher. You control the price, but the order may never fill if the market doesn't reach it."),
                    .heading("Stop and stop-limit orders"),
                    .bullets([
                        "A stop order waits until the price reaches your stop price, then becomes a market order. Traders often use a sell stop to exit a losing trade.",
                        "A stop-limit order becomes a limit order when the stop price is reached. It protects your price, but in a sudden drop it may not fill at all.",
                        "Most brokers also let you choose how long an order lasts: just for today (day) or until you cancel it (good till canceled)."
                    ]),
                    .example(title: "A buy limit", lines: [
                        "A stock trades at $52.",
                        "You place a buy limit at $50.",
                        "If the price dips to $50 or lower, your order can fill.",
                        "If it never drops to $50, you never buy."
                    ]),
                    .tip("Double-check the order type, quantity and price before you send it. A typo can be expensive.")
                ],
                takeaways: [
                    "Market orders favor speed; limit orders favor price.",
                    "A stop order turns into a market order when the stop price is hit.",
                    "A stop-limit can fail to fill in a fast move."
                ]
            ),
            LearnLesson(
                id: "basics-bid-ask",
                title: "Bid, ask and the spread",
                summary: "The two prices behind every quote",
                minutes: 2,
                blocks: [
                    .paragraph("Every quote really has two prices. Knowing them helps you understand what a trade actually costs."),
                    .heading("Two sides of a quote"),
                    .bullets([
                        "The bid is the highest price a buyer is offering right now. It's what you'd get if you sold immediately.",
                        "The ask (or offer) is the lowest price a seller will accept. It's what you'd pay if you bought immediately.",
                        "The spread is the gap between the two."
                    ]),
                    .example(title: "The cost of the spread", lines: [
                        "Bid $100.00, ask $100.05. The spread is $0.05.",
                        "You buy 100 shares at market: you pay $100.05.",
                        "You sell right away at market: you get $100.00.",
                        "You've lost $5 without the price moving at all."
                    ]),
                    .heading("Liquidity matters"),
                    .paragraph("Popular stocks and major currency pairs usually have tight spreads, because many people trade them all day. Small stocks, far-out options and lesser-known coins can have wide spreads. A wide spread means you start each trade further behind."),
                    .paragraph("Spreads also tend to widen outside regular hours and around big news, when fewer people are trading."),
                    .tip("On a wide spread, a limit order placed between the bid and ask can get you a better price than a market order.")
                ],
                takeaways: [
                    "You buy at the ask and sell at the bid.",
                    "The spread is a real cost on every round trip.",
                    "Less liquid markets usually have wider spreads."
                ]
            ),
            LearnLesson(
                id: "basics-market-hours",
                title: "Market hours",
                summary: "When stocks, crypto and forex trade",
                minutes: 2,
                blocks: [
                    .paragraph("Markets don't all keep the same hours. When you trade affects how easily your order fills and how much prices can jump."),
                    .heading("US stocks and options"),
                    .bullets([
                        "Regular hours run 9:30 a.m. to 4:00 p.m. Eastern Time, Monday to Friday, except market holidays.",
                        "Pre-market trading happens before the open and after-hours trading after the close. Times vary by broker.",
                        "Most options trade only during regular hours."
                    ]),
                    .paragraph("Outside regular hours, fewer people trade. Spreads get wider and prices can move sharply on small orders. Many brokers accept only limit orders then."),
                    .heading("Gaps"),
                    .paragraph("News often comes out while the stock market is closed, such as earnings after the close. The next morning the stock can open far from where it closed. This jump is called a gap, and your stop order can't protect you inside it."),
                    .heading("Crypto and forex"),
                    .bullets([
                        "Crypto trades around the clock, every day, including weekends.",
                        "Forex trades 24 hours a day, five days a week, from Sunday evening to Friday evening Eastern Time.",
                        "Round-the-clock markets can move a lot while you sleep."
                    ]),
                    .tip("If you can't watch a market, plan your exits before you enter.")
                ],
                takeaways: [
                    "US stocks trade 9:30 a.m. to 4:00 p.m. ET on weekdays.",
                    "Extended hours have thinner trading and wider spreads.",
                    "Crypto never closes; forex runs 24 hours on weekdays."
                ]
            ),
            LearnLesson(
                id: "basics-brokers",
                title: "Brokers and accounts",
                summary: "Cash vs margin, fees, protection and paper trading",
                minutes: 3,
                blocks: [
                    .paragraph("You don't trade on an exchange directly. A broker sends your orders to the market, holds your money and positions, and keeps records for taxes."),
                    .heading("Cash and margin accounts"),
                    .bullets([
                        "In a cash account you can only spend money you've deposited.",
                        "A margin account lets you borrow from the broker to buy more. Gains and losses both grow, and you pay interest on the loan.",
                        "If a margin account falls too far, the broker can ask for more money (a margin call) or sell your positions for you."
                    ]),
                    .paragraph("Most beginners are better off starting with a cash account."),
                    .heading("Costs and features"),
                    .bullets([
                        "Many brokers charge no commission on stocks, but you still pay the spread. Options often have a fee per contract.",
                        "Fractional shares let you buy part of a share, so a high stock price doesn't lock you out.",
                        "Crypto platforms often charge a percentage fee or a wider spread."
                    ]),
                    .heading("Protection"),
                    .paragraph("Choose a regulated broker. In the US, SIPC protects your account up to set limits if the broker itself fails. It doesn't protect you from losing money on trades. Crypto platforms usually don't have this kind of protection."),
                    .heading("Practice first"),
                    .paragraph("Many brokers offer paper trading: a practice account with pretend money. It's a free way to learn order types and test a plan before risking real money."),
                    .tip("Never give anyone your broker login. A legitimate mentor or community never needs it.")
                ],
                takeaways: [
                    "A broker routes your orders and holds your account.",
                    "Margin magnifies losses as well as gains.",
                    "Account protection covers broker failure, not trading losses.",
                    "Paper trading lets you practice without risk."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "basics-q1",
                prompt: "You want to buy a stock, but only at $40 or less. Which order fits?",
                options: ["Market order", "Buy limit at $40", "Sell stop at $40", "Buy stop at $40"],
                answerIndex: 1,
                explanation: "A buy limit order fills only at your limit price or lower, so you won't pay more than $40."
            ),
            LearnQuizQuestion(
                id: "basics-q2",
                prompt: "The bid is $20.00 and the ask is $20.10. If you buy at market, what do you pay?",
                options: ["$20.00", "$20.05", "$20.10"],
                answerIndex: 2,
                explanation: "Buying at market fills at the ask, the lowest price a seller will accept."
            ),
            LearnQuizQuestion(
                id: "basics-q3",
                prompt: "Which market trades every day, including weekends?",
                options: ["Crypto", "US stocks", "Forex", "US options"],
                answerIndex: 0,
                explanation: "Crypto trades around the clock. Forex runs 24 hours but only on weekdays."
            ),
            LearnQuizQuestion(
                id: "basics-q4",
                prompt: "What does account protection like SIPC cover?",
                options: ["Losses from bad trades", "Your broker failing, up to set limits", "Any drop in the market", "Crypto held on an exchange"],
                answerIndex: 1,
                explanation: "It helps if the broker itself fails. It never covers losses from trading."
            )
        ]
    )

    // MARK: - Risk management

    static let riskTrack = LearnTrack(
        id: "risk",
        title: "Risk management",
        subtitle: "Size positions and protect your account",
        systemImage: "shield.lefthalf.filled",
        tint: .teal,
        lessons: [
            LearnLesson(
                id: "risk-why-risk-first",
                title: "Why risk comes first",
                summary: "Staying in the game matters more than any one trade",
                minutes: 2,
                blocks: [
                    .paragraph("New traders often ask how much they can make. Experienced traders ask how much they could lose. The second question is the one that keeps you trading."),
                    .heading("Losses are harder to undo"),
                    .paragraph("A loss needs a bigger gain to recover. The deeper the hole, the harder the climb."),
                    .example(title: "The recovery math", lines: [
                        "Lose 10%: you need about 11% to get back to even.",
                        "Lose 25%: you need about 33%.",
                        "Lose 50%: you need 100%.",
                        "Lose 75%: you need 300%."
                    ]),
                    .heading("You will be wrong often"),
                    .paragraph("Even skilled traders lose on many of their trades. Losing streaks happen to everyone. What separates traders who last is that their losses stay small, so a streak doesn't wipe them out."),
                    .bullets([
                        "Decide how much you'll risk before you enter, not after.",
                        "Know exactly where you'll exit if you're wrong.",
                        "Only trade with money you can afford to lose."
                    ]),
                    .heading("Risk is something you control"),
                    .paragraph("You can't control where a price goes. You can control how big your position is, where your stop sits and how many trades you take. The rest of this track shows how."),
                    .tip("A good trade is one that followed your plan, even if it lost money.")
                ],
                takeaways: [
                    "Big losses need much bigger gains to recover.",
                    "Losing trades and losing streaks are normal.",
                    "Position size and exits are the parts you control."
                ]
            ),
            LearnLesson(
                id: "risk-position-sizing",
                title: "Position sizing",
                summary: "How many shares to buy, worked out from your stop",
                minutes: 3,
                blocks: [
                    .paragraph("Position sizing answers one question: how much should I buy? The answer doesn't come from how confident you feel. It comes from how much you're willing to lose and where your stop is."),
                    .heading("The formula"),
                    .bullets([
                        "Dollar risk = account size x risk percent.",
                        "Risk per share = entry price minus stop price.",
                        "Shares = dollar risk divided by risk per share."
                    ]),
                    .example(title: "Working it out", lines: [
                        "Account: $10,000. Risk: 1%, so $100.",
                        "Entry: $50. Stop: $48.",
                        "Risk per share: $50 - $48 = $2.",
                        "Shares: $100 / $2 = 50 shares.",
                        "Position value: 50 x $50 = $2,500.",
                        "If the stop is hit, you lose about $100, or 1% of the account."
                    ]),
                    .tool(.positionSize),
                    .heading("What this changes"),
                    .paragraph("Notice that the position is worth $2,500, but you're only risking $100. Position size and risk are not the same thing. A wider stop means fewer shares; a tighter stop allows more shares for the same dollar risk."),
                    .bullets([
                        "Every trade risks about the same amount, so no single trade can hurt you badly.",
                        "You set the stop first, based on the chart, then size the trade to fit it.",
                        "Round down to whole shares if your broker doesn't offer fractions."
                    ]),
                    .tip("Real losses can be bigger than planned if the price gaps past your stop. Leave yourself some room.")
                ],
                takeaways: [
                    "Shares = dollar risk divided by (entry minus stop).",
                    "Pick the stop first, then size the position.",
                    "Position value and amount at risk are different numbers."
                ]
            ),
            LearnLesson(
                id: "risk-one-percent-rule",
                title: "The 1–2% rule",
                summary: "A simple cap on how much any trade can cost you",
                minutes: 2,
                blocks: [
                    .paragraph("A common guideline is to risk no more than 1 to 2 percent of your account on any single trade. Many beginners start at 1% or less."),
                    .heading("Why such a small number"),
                    .paragraph("Small risk lets you survive the losing streaks every trader has. With 1% risk, ten losses in a row leaves you with roughly 90% of your account. With 10% risk, the same streak leaves you with about a third."),
                    .example(title: "Ten losses in a row", lines: [
                        "Risking 1% per trade: about $9,040 left of $10,000.",
                        "Risking 2% per trade: about $8,170 left.",
                        "Risking 10% per trade: about $3,490 left."
                    ]),
                    .heading("Using the rule"),
                    .bullets([
                        "Base the percent on your current account value, so your risk shrinks after losses and grows after gains.",
                        "The rule limits your loss if your stop is hit. It isn't a limit on position size.",
                        "Count related trades together. Five tech stocks can fall on the same day."
                    ]),
                    .paragraph("Some traders also set a daily or weekly loss limit. Once it's hit, they stop trading until the next period. It's a simple brake on bad days."),
                    .tip("The rule is a ceiling, not a target. Risking less is always allowed.")
                ],
                takeaways: [
                    "Risk 1–2% or less of your account per trade.",
                    "Small risk keeps a losing streak survivable.",
                    "Watch for several trades that are really the same bet."
                ]
            ),
            LearnLesson(
                id: "risk-stop-losses",
                title: "Stop losses",
                summary: "Where to put them, and what they can't do",
                minutes: 3,
                blocks: [
                    .paragraph("A stop loss is the price where you admit a trade isn't working and get out. You can place it as an order with your broker, or as a firm rule you act on yourself."),
                    .heading("Where to place a stop"),
                    .paragraph("A good stop sits where your trade idea is proven wrong, not at a random dollar amount."),
                    .bullets([
                        "Just below a recent low or support level for a long trade.",
                        "Just above a recent high or resistance level for a short trade.",
                        "Outside normal day-to-day wiggles, so ordinary noise doesn't knock you out."
                    ]),
                    .paragraph("Once you know where the stop goes, use position sizing to decide how much to buy."),
                    .heading("What stops can't do"),
                    .bullets([
                        "A stop order becomes a market order, so in a fast move you may get filled below your stop. This is called slippage.",
                        "If a stock gaps down overnight, it can open far below your stop, and you'll get the opening price.",
                        "Some option and crypto markets move so quickly that stops fill well away from where you set them."
                    ]),
                    .heading("Never widen a stop"),
                    .paragraph("When price gets close to a stop, it's tempting to move it further away to give the trade more room. This turns a small planned loss into a large unplanned one. You can move a stop to lock in profit, but don't move it to take on more risk."),
                    .tip("Set your stop before you enter, while you're calm.")
                ],
                takeaways: [
                    "Place stops where the trade idea is proven wrong.",
                    "Slippage and gaps can make losses bigger than planned.",
                    "Move stops only to reduce risk, never to add it."
                ]
            ),
            LearnLesson(
                id: "risk-reward",
                title: "Risk/reward",
                summary: "Comparing what you could lose with what you could make",
                minutes: 3,
                blocks: [
                    .paragraph("Risk/reward compares how much you stand to lose with how much you hope to make. It helps you decide whether a trade is worth taking at all."),
                    .heading("Working it out"),
                    .example(title: "A 1:2 trade", lines: [
                        "Entry: $50. Stop: $48. Target: $54.",
                        "Risk: $50 - $48 = $2 per share.",
                        "Reward: $54 - $50 = $4 per share.",
                        "Risk/reward: $2 to $4, or 1:2."
                    ]),
                    .heading("Win rate and breakeven"),
                    .paragraph("Risk/reward and win rate work together. The bigger your reward compared with your risk, the fewer trades you need to win to break even."),
                    .bullets([
                        "Breakeven win rate = risk divided by (risk + reward).",
                        "At 1:1 you need to win 50% of trades to break even.",
                        "At 1:2 you need about 33%.",
                        "At 1:3 you need 25%."
                    ]),
                    .example(title: "Ten trades at 1:2", lines: [
                        "Risk $100 per trade to make $200.",
                        "Win 4, lose 6.",
                        "Wins: 4 x $200 = $800. Losses: 6 x $100 = $600.",
                        "Result: +$200 before fees, with fewer than half the trades winning."
                    ]),
                    .heading("Keep it realistic"),
                    .paragraph("A target only counts if price can reasonably get there. Setting a far-away target makes the ratio look great on paper but may lower your win rate. Fees and slippage also eat into small edges."),
                    .tip("If a trade doesn't offer enough reward for its risk, skipping it is a valid choice.")
                ],
                takeaways: [
                    "Risk/reward compares your stop distance with your target distance.",
                    "Breakeven win rate = risk / (risk + reward).",
                    "A realistic target matters more than an impressive ratio."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "risk-q1",
                prompt: "Account $20,000, risk 1%, entry $40, stop $38. How many shares?",
                options: ["50 shares", "100 shares", "200 shares", "500 shares"],
                answerIndex: 1,
                explanation: "1% of $20,000 is $200. Risk per share is $2, so $200 / $2 = 100 shares."
            ),
            LearnQuizQuestion(
                id: "risk-q2",
                prompt: "Price is nearing your stop. What should you do with the stop?",
                options: ["Move it further away to give the trade room", "Leave it, or tighten it to reduce risk", "Cancel it and wait for a bounce"],
                answerIndex: 1,
                explanation: "Widening or removing a stop turns a planned small loss into an unplanned big one."
            ),
            LearnQuizQuestion(
                id: "risk-q3",
                prompt: "With a 1:3 risk/reward, what win rate do you need to break even, before fees?",
                options: ["75%", "50%", "33%", "25%"],
                answerIndex: 3,
                explanation: "Breakeven is risk / (risk + reward) = 1 / 4, or 25%."
            ),
            LearnQuizQuestion(
                id: "risk-q4",
                prompt: "Why can a loss end up bigger than your stop suggested?",
                options: ["Slippage and price gaps", "The 1% rule", "Using a limit order to enter"],
                answerIndex: 0,
                explanation: "A stop becomes a market order, so fast moves and overnight gaps can fill it below your stop price."
            )
        ]
    )
}
