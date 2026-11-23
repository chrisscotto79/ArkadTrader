// File: Core/Learn/LearnContent+Charts.swift
// Learn content: the Reading charts and Options basics tracks.

import Foundation

extension LearnContent {

    // MARK: - Reading charts

    static let chartsTrack = LearnTrack(
        id: "charts",
        title: "Reading charts",
        subtitle: "Candles, timeframes, levels, volume and trends",
        systemImage: "chart.xyaxis.line",
        tint: .blue,
        lessons: [
            LearnLesson(
                id: "charts-candlesticks",
                title: "Candlesticks",
                summary: "What each candle tells you about price",
                minutes: 3,
                blocks: [
                    .paragraph("A candlestick chart shows how price moved during a set period of time. Each candle covers one period, such as one minute, one hour or one day. It packs four prices into one simple shape."),
                    .heading("The four prices"),
                    .bullets([
                        "Open: the first traded price of the period.",
                        "High: the highest price reached.",
                        "Low: the lowest price reached.",
                        "Close: the last traded price of the period."
                    ]),
                    .heading("Bodies and wicks"),
                    .paragraph("The thick part of the candle is the body. It runs from the open to the close. If the close is above the open, the candle is usually green (or hollow). If the close is below the open, it is usually red (or filled)."),
                    .paragraph("The thin lines above and below the body are the wicks, also called shadows. They show the high and the low. A long wick means price went far in one direction but was pushed back before the period ended."),
                    .example(title: "Reading one daily candle", lines: [
                        "Open $50, high $54, low $49, close $53",
                        "Close is above open, so the candle is green",
                        "Body runs from $50 to $53",
                        "Upper wick from $53 to $54, lower wick from $49 to $50",
                        "Buyers were in control for most of the day"
                    ]),
                    .heading("Keep it in context"),
                    .paragraph("One candle on its own says very little. Patterns with names like 'hammer' or 'doji' can be useful, but they work far better when you look at where they form, such as near a support level, and at the candles around them."),
                    .tip("Colors can be changed in most charting apps. Always check which color means up and which means down on the chart you are using.")
                ],
                takeaways: [
                    "Each candle shows the open, high, low and close for one period.",
                    "The body spans open to close; the wicks show the high and low.",
                    "Long wicks show prices that were reached but rejected.",
                    "Read candles in context, not one at a time."
                ]
            ),
            LearnLesson(
                id: "charts-timeframes",
                title: "Timeframes",
                summary: "Pick the chart that matches how long you hold",
                minutes: 2,
                blocks: [
                    .paragraph("The timeframe is how much time each candle covers. The same stock can look like it is rising on one timeframe and falling on another. Choosing the right one keeps your analysis matched to your plan."),
                    .heading("Common timeframes"),
                    .bullets([
                        "1 minute and 5 minute: used by day traders for very short moves.",
                        "15 minute and 1 hour: intraday swings and planning entries.",
                        "Daily: each candle is one trading day. Popular with swing traders.",
                        "Weekly: each candle is one week. Shows the big picture."
                    ]),
                    .heading("Match the chart to your holding period"),
                    .paragraph("If you plan to hold a trade for a few weeks, a 1 minute chart is mostly noise. If you plan to hold for an hour, a weekly chart moves too slowly to help with timing. A simple rule is to plan on the timeframe that fits how long you expect to hold."),
                    .heading("Check one timeframe higher"),
                    .paragraph("Before you trade, zoom out one step. A day trader using 5 minute candles might check the hourly chart. A swing trader using the daily chart might check the weekly. This shows the bigger trend and any major levels just above or below the price."),
                    .tip("Shorter timeframes produce many more signals, and many of them are false. More signals does not mean more good trades.")
                ],
                takeaways: [
                    "The timeframe is how much time one candle covers.",
                    "Use the timeframe that matches how long you plan to hold.",
                    "Check the next higher timeframe for the bigger trend.",
                    "Short timeframes are noisier and give more false signals."
                ]
            ),
            LearnLesson(
                id: "charts-support-resistance",
                title: "Support and resistance",
                summary: "Price areas where buyers or sellers showed up",
                minutes: 3,
                blocks: [
                    .paragraph("Support is a price area where falling prices have tended to stop, because buyers stepped in. Resistance is a price area where rising prices have tended to stall, because sellers stepped in. Traders use these areas to plan entries, exits and stop losses."),
                    .heading("Think in zones, not exact lines"),
                    .paragraph("Price rarely turns at the exact same cent twice. It is more useful to mark a zone, such as $48 to $49, than a single line at $48.50. The more times price has reacted to a zone, the more attention traders tend to pay to it."),
                    .bullets([
                        "Look for areas where price turned more than once.",
                        "Round numbers like $50 or $100 often attract orders.",
                        "Recent levels usually matter more than very old ones."
                    ]),
                    .heading("Role reversal"),
                    .paragraph("When price breaks clearly through resistance, that old resistance often becomes new support. The opposite also happens: broken support can turn into resistance. Traders sometimes wait for price to come back and test the broken level before acting."),
                    .example(title: "A level flipping", lines: [
                        "A stock stalls near $60 three times in two months",
                        "It finally closes at $63 on strong volume",
                        "A week later it dips back to about $60 and holds",
                        "The old ceiling at $60 is now acting as a floor"
                    ]),
                    .heading("Why levels fail"),
                    .paragraph("Support and resistance describe past behavior, not a promise. News, earnings or a shift in the wider market can push straight through any level. That is why a plan should always say what you will do if the level breaks."),
                    .tip("Many traders place stops just beyond a zone, not exactly on it, so a small poke through does not stop them out.")
                ],
                takeaways: [
                    "Support is where buyers have stepped in; resistance is where sellers have.",
                    "Mark zones rather than exact prices.",
                    "Broken resistance often becomes support, and the reverse.",
                    "Levels can fail, so always plan for a break."
                ]
            ),
            LearnLesson(
                id: "charts-volume",
                title: "Volume",
                summary: "How much trading is behind a move",
                minutes: 2,
                blocks: [
                    .paragraph("Volume is the number of shares, contracts or coins traded in a period. It usually appears as bars under the price chart. Volume shows how much participation is behind a move."),
                    .heading("Volume as confirmation"),
                    .paragraph("A move on heavy volume means many traders took part. A move on light volume means few did. Many traders give more weight to price moves that come with above-average volume."),
                    .bullets([
                        "Rising price with rising volume suggests strong interest from buyers.",
                        "Rising price with shrinking volume can mean the move is losing steam.",
                        "A sharp drop on very heavy volume can show sellers rushing out."
                    ]),
                    .heading("Breakouts on low volume"),
                    .paragraph("When price breaks above resistance but volume is low, the breakout is more likely to fail and slip back into the old range. A breakout with clearly higher volume than usual is generally taken more seriously."),
                    .heading("Compare to average volume"),
                    .paragraph("Raw volume numbers mean little on their own. A popular large company may trade tens of millions of shares a day, while a small company trades a few hundred thousand. Compare today's volume to that asset's own average, often the last 20 or 50 days."),
                    .example(title: "Is this volume high?", lines: [
                        "Average daily volume: 2 million shares",
                        "Today's volume: 5 million shares",
                        "5 divided by 2 = 2.5 times normal volume",
                        "That is unusually heavy participation"
                    ]),
                    .tip("Very low volume also means it can be harder to get in and out at a fair price.")
                ],
                takeaways: [
                    "Volume shows how much trading is behind a move.",
                    "Moves on above-average volume carry more weight.",
                    "Breakouts on low volume fail more often.",
                    "Compare volume to the asset's own average."
                ]
            ),
            LearnLesson(
                id: "charts-trends",
                title: "Trends and ranges",
                summary: "Spot the direction price is moving, or not",
                minutes: 3,
                blocks: [
                    .paragraph("A trend is the general direction price is moving over time. Markets do not move in straight lines. They move in waves, and the pattern of those waves tells you whether a trend is up, down or sideways."),
                    .heading("Highs and lows"),
                    .bullets([
                        "Uptrend: a series of higher highs and higher lows.",
                        "Downtrend: a series of lower highs and lower lows.",
                        "Range: price moves sideways between a ceiling and a floor."
                    ]),
                    .paragraph("An uptrend is often considered intact until price makes a lower low. That is one simple way to notice when a trend may be ending."),
                    .heading("Moving averages, in plain words"),
                    .paragraph("A moving average is the average closing price over a set number of recent periods, redrawn each period. A 50-day moving average is the average of the last 50 daily closes. It smooths out the noise so the direction is easier to see."),
                    .bullets([
                        "Price above a rising average suggests an uptrend.",
                        "Price below a falling average suggests a downtrend.",
                        "A flat average with price crossing back and forth suggests a range."
                    ]),
                    .heading("Trendlines and ranges"),
                    .paragraph("A trendline connects two or more lows in an uptrend, or two or more highs in a downtrend. It gives you a visual guide to where price has found support. In a range, traders watch the top and bottom of the range instead, and wait to see which side breaks."),
                    .tip("Moving averages are based on past prices, so they always lag. They describe the trend; they do not predict it.")
                ],
                takeaways: [
                    "Uptrends make higher highs and higher lows; downtrends do the opposite.",
                    "Moving averages smooth price to show direction, but they lag.",
                    "Trendlines connect lows in an uptrend or highs in a downtrend.",
                    "In a range, watch the top and bottom for a break."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "charts-q1",
                prompt: "On a candlestick, what do the wicks show?",
                options: [
                    "The open and close",
                    "The high and low of the period",
                    "The trading volume",
                    "The moving average"
                ],
                answerIndex: 1,
                explanation: "The body runs from open to close. The wicks extend to the highest and lowest prices reached during the period."
            ),
            LearnQuizQuestion(
                id: "charts-q2",
                prompt: "A stock breaks above resistance on volume well below its average. What does that suggest?",
                options: [
                    "The breakout is guaranteed to continue",
                    "Volume does not matter for breakouts",
                    "The breakout has a higher chance of failing"
                ],
                answerIndex: 2,
                explanation: "Breakouts on light volume have less participation behind them and fail more often than breakouts on heavy volume."
            ),
            LearnQuizQuestion(
                id: "charts-q3",
                prompt: "Which pattern describes an uptrend?",
                options: [
                    "Higher highs and higher lows",
                    "Lower highs and lower lows",
                    "Equal highs and equal lows",
                    "Higher highs and lower lows"
                ],
                answerIndex: 0,
                explanation: "An uptrend is a series of higher highs and higher lows. A lower low is often the first sign it may be ending."
            ),
            LearnQuizQuestion(
                id: "charts-q4",
                prompt: "Price breaks clearly above a resistance zone at $60. What often happens to that zone afterward?",
                options: [
                    "It disappears from the chart",
                    "It becomes stronger resistance",
                    "It can act as new support",
                    "It turns into the moving average"
                ],
                answerIndex: 2,
                explanation: "This is called role reversal. Broken resistance often becomes support, though like any level it can still fail."
            )
        ]
    )

    // MARK: - Options basics

    static let optionsTrack = LearnTrack(
        id: "options",
        title: "Options basics",
        subtitle: "Calls, puts, premium, the Greeks and the risks",
        systemImage: "square.stack.3d.up.fill",
        tint: .purple,
        lessons: [
            LearnLesson(
                id: "options-calls-puts",
                title: "Calls and puts",
                summary: "Rights for buyers, obligations for sellers",
                minutes: 3,
                blocks: [
                    .paragraph("An option is a contract tied to an underlying asset, such as a stock. It gives the buyer a right, but not an obligation, to buy or sell that asset at a set price before a set date. There are two basic types."),
                    .heading("Calls and puts"),
                    .bullets([
                        "A call gives the buyer the right to buy the underlying at the strike price.",
                        "A put gives the buyer the right to sell the underlying at the strike price.",
                        "Call buyers generally benefit if the price rises.",
                        "Put buyers generally benefit if the price falls."
                    ]),
                    .heading("Buyers and sellers"),
                    .paragraph("Every option has a buyer and a seller. The buyer pays a price, called the premium, and gets the right. The seller, also called the writer, receives the premium and takes on an obligation."),
                    .bullets([
                        "If a call buyer exercises, the call seller must sell the shares at the strike.",
                        "If a put buyer exercises, the put seller must buy the shares at the strike.",
                        "The buyer's loss is limited to the premium paid.",
                        "The seller's risk can be much larger than the premium received."
                    ]),
                    .example(title: "A simple call", lines: [
                        "Stock trades at $100",
                        "You buy a call with a $105 strike",
                        "If the stock rises to $115 before expiry, you can buy at $105",
                        "If it stays below $105, the call may expire worthless"
                    ]),
                    .tip("Buying an option and selling an option are very different trades with very different risks. Learn both sides before you trade either.")
                ],
                takeaways: [
                    "A call is the right to buy; a put is the right to sell.",
                    "Buyers pay a premium and have rights, not obligations.",
                    "Sellers collect the premium and take on obligations.",
                    "A buyer can lose at most the premium; a seller can lose more."
                ]
            ),
            LearnLesson(
                id: "options-strike-expiry",
                title: "Strike and expiry",
                summary: "The price and the deadline of a contract",
                minutes: 3,
                blocks: [
                    .paragraph("Every option has two key terms. The strike price is the price at which the underlying can be bought or sold. The expiration date, or expiry, is the last day the contract is valid. After expiry, the option no longer exists."),
                    .heading("In, at or out of the money"),
                    .paragraph("Moneyness describes where the strike sits compared to the current price of the underlying."),
                    .bullets([
                        "In the money (ITM): a call with a strike below the stock price, or a put with a strike above it.",
                        "At the money (ATM): the strike is at or very near the stock price.",
                        "Out of the money (OTM): a call with a strike above the stock price, or a put with a strike below it."
                    ]),
                    .example(title: "Stock at $50", lines: [
                        "$45 call: in the money by $5",
                        "$50 call: at the money",
                        "$55 call: out of the money",
                        "$55 put: in the money by $5"
                    ]),
                    .heading("Choosing an expiry"),
                    .paragraph("Options can expire in days, weeks, months or even years. Longer expiries give the trade more time to work, but they usually cost more. Very short expiries are cheaper, but they lose value quickly and can expire worthless in a short time."),
                    .heading("American and European exercise"),
                    .paragraph("American-style options can be exercised any time up to expiry. Most US stock options are American style. European-style options can only be exercised at expiry. Many index options are European style.")
                ],
                takeaways: [
                    "The strike is the contract price; the expiry is its deadline.",
                    "ITM, ATM and OTM describe the strike versus the current price.",
                    "Longer expiries cost more but give more time.",
                    "Most US stock options are American style and can be exercised early."
                ]
            ),
            LearnLesson(
                id: "options-premium",
                title: "Premium",
                summary: "What an option costs and why",
                minutes: 3,
                blocks: [
                    .paragraph("The premium is the price of an option. It is quoted per share, but a standard US stock option contract covers 100 shares. So you multiply the quoted premium by 100 to get the cost of one contract."),
                    .heading("Intrinsic value and time value"),
                    .paragraph("Premium has two parts."),
                    .bullets([
                        "Intrinsic value: how much the option is in the money right now. Out of the money options have zero intrinsic value.",
                        "Time value: everything above intrinsic value. It reflects the time left and how much the price is expected to move."
                    ]),
                    .paragraph("Time value shrinks as expiry gets closer. At expiry, an option is worth only its intrinsic value, if any."),
                    .example(title: "Buying one call contract", lines: [
                        "Stock trades at $52",
                        "$50 call, premium quoted at $2.50",
                        "Cost: $2.50 x 100 shares = $250",
                        "Intrinsic value: $52 - $50 = $2.00",
                        "Time value: $2.50 - $2.00 = $0.50",
                        "Breakeven at expiry: $50 strike + $2.50 premium = $52.50"
                    ]),
                    .heading("Breakeven"),
                    .paragraph("For a call buyer, the breakeven at expiry is the strike plus the premium paid. For a put buyer, it is the strike minus the premium paid. The stock has to move past that point, not just past the strike, for the trade to profit at expiry."),
                    .tip("Fees and the bid/ask spread also eat into results. Include them when you work out what a trade really costs.")
                ],
                takeaways: [
                    "One standard contract covers 100 shares, so multiply the premium by 100.",
                    "Premium = intrinsic value + time value.",
                    "Time value fades toward zero at expiry.",
                    "Call breakeven at expiry = strike + premium; put breakeven = strike - premium."
                ]
            ),
            LearnLesson(
                id: "options-greeks",
                title: "The basic Greeks",
                summary: "How option prices react to change",
                minutes: 3,
                blocks: [
                    .paragraph("The Greeks are numbers that estimate how an option's price may change when something else changes. Most trading apps show them next to each contract. You do not need the math, but you should know what each one means."),
                    .heading("The four main Greeks"),
                    .bullets([
                        "Delta: about how much the option's price moves for a $1 move in the underlying.",
                        "Theta: about how much value the option loses each day from the passage of time.",
                        "Vega: about how much the price changes when implied volatility moves by one percentage point.",
                        "Gamma: how quickly delta itself changes as the underlying moves."
                    ]),
                    .example(title: "Reading the Greeks on one call", lines: [
                        "Premium $3.00, delta 0.50, theta -0.05",
                        "Stock rises $1: option rises about $0.50, or $50 per contract",
                        "One day passes with no move: option loses about $0.05, or $5 per contract",
                        "These are estimates, and they change as price and time change"
                    ]),
                    .heading("How to use them"),
                    .paragraph("Delta gives a rough sense of how much exposure you have to the stock. Calls have positive delta and puts have negative delta. Theta reminds you that time works against option buyers. Vega shows how sensitive the contract is to changes in expected volatility, which matters a lot around earnings."),
                    .paragraph("Gamma is usually highest for at the money options close to expiry. That is why those contracts can swing in value very quickly."),
                    .tip("The Greeks are estimates from a pricing model. Real prices can move differently, especially in fast markets.")
                ],
                takeaways: [
                    "Delta: sensitivity to the underlying's price.",
                    "Theta: daily loss of value from time passing.",
                    "Vega: sensitivity to implied volatility.",
                    "Gamma: how fast delta changes."
                ]
            ),
            LearnLesson(
                id: "options-risks",
                title: "The risks",
                summary: "How options trades go wrong",
                minutes: 3,
                blocks: [
                    .paragraph("Options can control a lot of stock for a small amount of money. That leverage cuts both ways. Many beginners lose money on options because they underestimate these risks."),
                    .heading("Risks for buyers"),
                    .bullets([
                        "Time decay: if the stock does not move enough, soon enough, the option loses value every day.",
                        "Total loss: an out of the money option at expiry is worth nothing. You can lose 100% of the premium.",
                        "Being right but too slow: the stock can move your way after the option has already expired."
                    ]),
                    .heading("Risks for sellers"),
                    .bullets([
                        "Selling a call without owning the shares (a naked call) has no upper limit on losses if the stock keeps rising.",
                        "Selling a naked put can mean buying the shares at the strike even after a big drop.",
                        "Assignment: an American-style option can be exercised early, and you must meet the obligation."
                    ]),
                    .heading("Market risks"),
                    .bullets([
                        "Liquidity: thinly traded contracts can have wide bid/ask spreads, so getting in and out costs more.",
                        "IV crush: implied volatility often drops sharply after earnings. An option can lose value even if the stock moves the way you expected."
                    ]),
                    .example(title: "IV crush after earnings", lines: [
                        "Before earnings, a call costs $4.00 because a big move is expected",
                        "The stock rises $2 after the report",
                        "Implied volatility falls, and the call is now worth $3.20",
                        "The direction was right, but the trade still lost money"
                    ]),
                    .tip("Brokers require approval levels for options trading. Start with defined-risk trades and small sizes while you learn.")
                ],
                takeaways: [
                    "Option buyers can lose 100% of the premium.",
                    "Selling naked options can lead to very large losses.",
                    "Wide spreads and IV crush can hurt even correct trades.",
                    "Sellers can be assigned before expiry."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "options-q1",
                prompt: "What does buying a put give you?",
                options: [
                    "The right to sell the underlying at the strike price",
                    "The obligation to buy the underlying at the strike price",
                    "The right to buy the underlying at the strike price"
                ],
                answerIndex: 0,
                explanation: "A put gives the buyer the right, but not the obligation, to sell at the strike. It's the seller of the put who has the obligation to buy."
            ),
            LearnQuizQuestion(
                id: "options-q2",
                prompt: "A call has a $40 strike and costs $1.50. What is the breakeven at expiry, and the cost of one contract?",
                options: [
                    "$38.50 and $15",
                    "$41.50 and $1.50",
                    "$40 and $150",
                    "$41.50 and $150"
                ],
                answerIndex: 3,
                explanation: "Call breakeven is strike plus premium: $40 + $1.50 = $41.50. One contract covers 100 shares, so it costs $1.50 x 100 = $150."
            ),
            LearnQuizQuestion(
                id: "options-q3",
                prompt: "Which Greek estimates how much value an option loses each day from time passing?",
                options: [
                    "Delta",
                    "Theta",
                    "Vega",
                    "Gamma"
                ],
                answerIndex: 1,
                explanation: "Theta measures time decay. It works against option buyers and in favor of option sellers."
            ),
            LearnQuizQuestion(
                id: "options-q4",
                prompt: "You buy a call before earnings. The stock rises a little, but your call loses value. What is a likely cause?",
                options: [
                    "The stock split",
                    "Gamma became negative",
                    "Implied volatility dropped after the report",
                    "The call became in the money"
                ],
                answerIndex: 2,
                explanation: "This is IV crush. Option prices often include a high expected move before earnings, and that extra value can vanish once the news is out."
            )
        ]
    )
}
