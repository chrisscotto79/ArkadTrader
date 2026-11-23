// File: Core/Learn/LearnContent+Mindset.swift
// Learn tracks: Trading psychology and Using communities safely.

import Foundation

extension LearnContent {

    // MARK: - Trading psychology

    static let psychologyTrack = LearnTrack(
        id: "psychology",
        title: "Trading psychology",
        subtitle: "Manage FOMO, losses and your own habits",
        systemImage: "brain.head.profile",
        tint: .pink,
        lessons: [
            LearnLesson(
                id: "psychology-fomo",
                title: "FOMO: the fear of missing out",
                summary: "Why chasing moves hurts, and how to wait for your setup",
                minutes: 2,
                blocks: [
                    .paragraph("FOMO is the urge to jump into a trade because a price is moving fast and everyone seems to be making money. It feels urgent. That urgency is exactly why it leads to poor trades."),
                    .heading("What chasing looks like"),
                    .paragraph("You see a stock up 15% today. You buy near the top because you don't want to miss more gains. Often the move is already late, and early buyers start taking profits as you get in."),
                    .bullets([
                        "Buying after a big candle with no plan for where to exit",
                        "Entering because a chat or post is excited, not because of your own setup",
                        "Using a bigger size than usual to make up for being late",
                        "Skipping your stop loss because you expect the move to continue"
                    ]),
                    .heading("Missing a move is fine"),
                    .paragraph("There will always be another trade. Markets move every day, and no one catches every move. A missed opportunity costs you nothing. A chased trade can cost you real money."),
                    .heading("Wait for your setup"),
                    .paragraph("Decide in advance what a good entry looks like for you. It might be a pullback to support, a breakout on strong volume, or a specific price. If the market doesn't give you that, you don't trade."),
                    .tip("When you feel rushed, pause for five minutes before placing an order. If the trade still fits your plan after the pause, you can take it. If it doesn't, you've avoided an impulse decision.")
                ],
                takeaways: [
                    "FOMO is urgency, and urgency leads to rushed, unplanned trades.",
                    "Missing a move costs nothing. Chasing one can cost a lot.",
                    "Define your entry before the market moves, then wait for it.",
                    "A short pause before ordering helps you separate plans from impulses."
                ]
            ),
            LearnLesson(
                id: "psychology-revenge-trading",
                title: "Revenge trading",
                summary: "Trying to win back a loss right away, and how to stop",
                minutes: 2,
                blocks: [
                    .paragraph("Revenge trading is jumping into a new trade right after a loss, mainly to win the money back. The goal shifts from following your plan to fixing how you feel. That rarely ends well."),
                    .heading("Why it happens"),
                    .paragraph("Losses hurt more than gains feel good. After a loss, it's natural to want to erase it quickly. Many traders then take larger positions, lower-quality setups, or trade markets they don't know."),
                    .bullets([
                        "Doubling your size on the next trade to recover faster",
                        "Taking trades that don't match your usual rules",
                        "Trading more often than normal after a red day",
                        "Moving or removing stops so you don't have to take another loss"
                    ]),
                    .heading("Set a daily loss limit"),
                    .paragraph("A daily loss limit is a fixed amount you're willing to lose in one day. Once you hit it, you stop trading until tomorrow. It caps the damage on a bad day before emotions take over."),
                    .example(title: "A simple daily limit", lines: [
                        "Account size: $5,000",
                        "Daily loss limit: 3% of the account",
                        "3% of $5,000 = $150",
                        "After losing $150 in a day, you stop trading until the next day"
                    ]),
                    .heading("Step away"),
                    .paragraph("After a loss, close the chart. Take a walk or do something unrelated. Come back later and review the trade calmly. A clear head makes better decisions than a frustrated one.")
                ],
                takeaways: [
                    "Revenge trading is trying to win back a loss instead of following your plan.",
                    "It usually means bigger size and weaker setups, which increases risk.",
                    "A daily loss limit tells you when to stop for the day.",
                    "Stepping away after a loss is a skill, not a weakness."
                ]
            ),
            LearnLesson(
                id: "psychology-journaling",
                title: "Keeping a trading journal",
                summary: "What to record after each trade, and how to review it",
                minutes: 3,
                blocks: [
                    .paragraph("A trading journal is a record of every trade you take and why. Memory is unreliable. A journal shows you what actually works for you and which habits keep costing you money."),
                    .heading("What to record"),
                    .paragraph("Write each entry when you open and close the trade, while the details are fresh. Keep it short so you actually do it."),
                    .bullets([
                        "Setup: what pattern or idea made you consider the trade",
                        "Entry and exit: the prices and times you got in and out",
                        "Size: how many shares, contracts or units, and the amount at risk",
                        "Reason: why you entered, in one or two sentences",
                        "Emotion: how you felt before and during the trade, such as calm, rushed or anxious",
                        "Outcome: the result, and whether you followed your plan"
                    ]),
                    .heading("Review it weekly"),
                    .paragraph("Once a week, read through your entries. Look for patterns rather than single results. You might notice that your losing trades often start when you feel rushed, or that one setup works much better than another."),
                    .bullets([
                        "Which setups had the best results over many trades?",
                        "Which mistakes came up more than once?",
                        "Did you follow your plan on most trades?",
                        "What is one thing to change next week?"
                    ]),
                    .heading("Tools help"),
                    .paragraph("You can keep a journal in a notebook, a spreadsheet or an app. Logging trades in Arkad's portfolio records your entries, exits and notes in one place, which makes the weekly review easier."),
                    .tip("Record the emotion even when it feels silly. Over time, how you felt is often the clearest explanation for your worst trades.")
                ],
                takeaways: [
                    "A journal replaces unreliable memory with real data about your trading.",
                    "Record the setup, entry, exit, size, reason, emotion and outcome.",
                    "Review weekly and look for patterns, not single results.",
                    "Pick one specific thing to improve each week."
                ]
            ),
            LearnLesson(
                id: "psychology-discipline",
                title: "Discipline and a trading plan",
                summary: "Write your rules down and follow them before you enter",
                minutes: 2,
                blocks: [
                    .paragraph("Discipline in trading means doing what you planned, even when you feel like doing something else. It starts with a written plan, because rules that live only in your head are easy to bend."),
                    .heading("What a simple plan includes"),
                    .bullets([
                        "Which markets and timeframes you trade",
                        "The setups you take, described clearly",
                        "How much you risk per trade, such as 1% of your account",
                        "Where your stop loss and target go before you enter",
                        "Your daily loss limit and when you stop for the day"
                    ]),
                    .heading("Rules before entering"),
                    .paragraph("Make the key decisions before you click buy. Once a trade is open, emotions get stronger and judgment gets weaker. A short checklist helps."),
                    .example(title: "A pre-trade checklist", lines: [
                        "Does this match one of my setups? Yes or no",
                        "Do I know my entry, stop and target? Yes or no",
                        "Is my risk within my limit per trade? Yes or no",
                        "Am I calm, not rushed or upset? Yes or no",
                        "Any no means no trade"
                    ]),
                    .heading("Process over outcome"),
                    .paragraph("A single trade can win even if you broke your rules, and lose even if you followed them perfectly. Judge yourself on whether you followed the plan. Over many trades, good process is what you can control.")
                ],
                takeaways: [
                    "Discipline means following your plan when emotions push the other way.",
                    "Write your plan down: setups, risk per trade, stops and limits.",
                    "Decide entry, stop and target before you enter.",
                    "Measure yourself by process, because single outcomes are partly luck."
                ]
            ),
            LearnLesson(
                id: "psychology-wins-and-losses",
                title: "Handling wins and losses",
                summary: "Stay steady through streaks and judge decisions, not results",
                minutes: 2,
                blocks: [
                    .paragraph("Both winning and losing can push you off course. A hot streak can make you careless. A cold streak can make you quit a sound approach too early. The aim is to stay steady either way."),
                    .heading("Overconfidence after a streak"),
                    .paragraph("After several wins, it's easy to feel that you can't lose. Traders often raise their size, loosen their rules or skip their stops. One bad trade at a large size can undo weeks of progress."),
                    .bullets([
                        "Keep your risk per trade the same after a winning streak",
                        "Remember that some wins came partly from luck",
                        "Keep using your checklist on every trade"
                    ]),
                    .heading("Losing streaks are normal"),
                    .paragraph("Even a sound approach has runs of losses. If a strategy wins half the time, five losses in a row will still happen now and then. Small, consistent risk per trade is what lets you get through these runs."),
                    .heading("Judge decisions, not results"),
                    .paragraph("Ask whether the trade followed your plan, not just whether it made money. A planned trade that hit its stop was a good decision with a bad result. An impulsive trade that happened to win was a bad decision with a lucky result."),
                    .tip("If a losing streak goes beyond what you'd normally expect, cut your size and review your journal before trading more.")
                ],
                takeaways: [
                    "Winning streaks can lead to bigger size and looser rules. Keep both steady.",
                    "Losing streaks happen even with a sound approach.",
                    "Small, consistent risk per trade helps you survive bad runs.",
                    "Judge each trade by the decision, not only by the result."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "psychology-q1",
                prompt: "A stock is already up 20% today and you feel you must buy now. What's the most disciplined response?",
                options: [
                    "Buy immediately with extra size to catch up",
                    "Wait for a setup that fits your plan, even if that means missing the move",
                    "Buy now and skip the stop loss",
                    "Ask a chat room whether you should buy"
                ],
                answerIndex: 1,
                explanation: "That urge is FOMO. Missing a move costs nothing, while chasing an unplanned entry adds risk."
            ),
            LearnQuizQuestion(
                id: "psychology-q2",
                prompt: "What is a daily loss limit for?",
                options: [
                    "Making sure you win every day",
                    "Raising your size after a loss",
                    "Telling you when to stop trading for the day",
                    "Deciding which stocks to buy"
                ],
                answerIndex: 2,
                explanation: "A daily loss limit caps how much you can lose in one day, before emotions like revenge trading take over."
            ),
            LearnQuizQuestion(
                id: "psychology-q3",
                prompt: "Which of these is most useful to record in a trading journal?",
                options: [
                    "The setup, entry, exit, size, reason, emotion and outcome",
                    "Only the trades that made money",
                    "Only the final profit or loss",
                    "Other people's trades"
                ],
                answerIndex: 0,
                explanation: "Recording the full picture, including emotion, helps you find patterns when you review your trades."
            ),
            LearnQuizQuestion(
                id: "psychology-q4",
                prompt: "You followed your plan exactly and the trade hit its stop. How should you judge it?",
                options: [
                    "A mistake, because it lost money",
                    "A reason to abandon your plan",
                    "A sign to double your size next time",
                    "A good decision with a bad result"
                ],
                answerIndex: 3,
                explanation: "Single results include luck. Following a sound plan is the part you control, so it was a good decision."
            ),
            LearnQuizQuestion(
                id: "psychology-q5",
                prompt: "After five winning trades in a row, what should you do with your risk per trade?",
                options: [
                    "Increase it, since you're on a streak",
                    "Keep it the same",
                    "Stop using stop losses",
                    "Risk your whole account on the next trade"
                ],
                answerIndex: 1,
                explanation: "Streaks can create overconfidence. Keeping risk steady protects you when the next loss arrives."
            )
        ]
    )

    // MARK: - Using communities safely

    static let communitiesTrack = LearnTrack(
        id: "communities",
        title: "Using communities safely",
        subtitle: "Judge callouts and track records, and spot scams",
        systemImage: "person.3.fill",
        tint: .indigo,
        lessons: [
            LearnLesson(
                id: "communities-judge-callout",
                title: "How to judge a callout",
                summary: "What a good trade idea includes, and why you still check it",
                minutes: 2,
                blocks: [
                    .paragraph("A callout is a trade idea shared with a community. Callouts can be a great way to learn how experienced traders think. They are ideas, not instructions, and you're responsible for any trade you take."),
                    .heading("What a clear callout includes"),
                    .bullets([
                        "Entry: the price or range where the idea starts",
                        "Stop: where the idea is wrong and the trade should close",
                        "Target: where the trader plans to take profit",
                        "Reasoning: why they like the setup",
                        "Timeframe: whether it's a day trade, a swing trade or longer"
                    ]),
                    .paragraph("If a callout has no stop, no reasoning, or only says buy now, treat it with extra caution. Vague ideas make it impossible to manage risk."),
                    .heading("Do your own check"),
                    .paragraph("Look at the chart yourself. Ask whether the setup fits your own plan and the markets you understand. Never copy a trade blindly, especially one you can't explain."),
                    .heading("Size by your own risk"),
                    .paragraph("The person posting doesn't know your account. Use their entry and stop, but choose your size from your own risk per trade."),
                    .example(title: "Sizing a callout to your account", lines: [
                        "Callout: entry $50, stop $48",
                        "Risk per share: $50 - $48 = $2",
                        "Your account: $4,000, risking 1% = $40",
                        "Position size: $40 / $2 = 20 shares"
                    ])
                ],
                takeaways: [
                    "A good callout has an entry, stop, target, reasoning and timeframe.",
                    "Callouts are ideas, not instructions. Check the chart yourself.",
                    "Never copy a trade you can't explain.",
                    "Size every trade from your own account and risk, not someone else's."
                ]
            ),
            LearnLesson(
                id: "communities-track-records",
                title: "Reading a track record",
                summary: "Sample size, win rate versus average return, and cherry-picking",
                minutes: 3,
                blocks: [
                    .paragraph("A track record shows how a trader's past callouts turned out. It's useful, but only if you read it carefully. A few numbers can look impressive while telling you very little."),
                    .heading("Sample size matters"),
                    .paragraph("Five closed callouts is not much evidence. Anyone can have a good week. Dozens of closed callouts across different market conditions tell you far more."),
                    .heading("Closed versus open callouts"),
                    .paragraph("Only closed callouts have a final result. Open callouts can still go either way. Look at how many have closed, not just how many were posted."),
                    .heading("Win rate versus average return"),
                    .paragraph("Win rate is the share of callouts that made money. Average return is how much they made or lost on average. You need both."),
                    .example(title: "Two different traders", lines: [
                        "Trader A: 80% win rate, wins average +2%, losses average -10%",
                        "Average per callout: 0.8 x 2 - 0.2 x 10 = -0.4%",
                        "Trader B: 40% win rate, wins average +8%, losses average -2%",
                        "Average per callout: 0.4 x 8 - 0.6 x 2 = +2.0%"
                    ]),
                    .paragraph("Trader A wins more often but loses money on average. Trader B wins less often but comes out ahead."),
                    .heading("Watch for cherry-picking"),
                    .bullets([
                        "Screenshots of only the best trades",
                        "Results with no losing trades at all",
                        "Records that start conveniently after a bad period"
                    ]),
                    .tip("Arkad tracks each callout against live prices and records the result when it closes, so the record includes losses as well as wins.")
                ],
                takeaways: [
                    "A small number of closed callouts means very little.",
                    "Only closed callouts have a final result.",
                    "Look at win rate and average return together.",
                    "Be wary of records that only show wins."
                ]
            ),
            LearnLesson(
                id: "communities-red-flags",
                title: "Red flags for scams and pump-and-dumps",
                summary: "Common warning signs and how to respond",
                minutes: 3,
                blocks: [
                    .paragraph("Most people in trading communities are there to learn and share. A few are there to take your money. Knowing the common warning signs makes you a much harder target."),
                    .heading("Classic red flags"),
                    .bullets([
                        "Guaranteed returns or no-risk claims. No real trade is risk-free",
                        "Urgency, such as buy in the next ten minutes or miss out forever",
                        "Pressure to buy tiny, thinly traded coins or penny stocks",
                        "Offers to manage your money if you send it to them",
                        "Direct messages from someone claiming to be support",
                        "Screenshots of huge gains that you can't verify"
                    ]),
                    .heading("How a pump-and-dump works"),
                    .paragraph("A group buys a small, illiquid stock or coin cheaply. They then hype it to others, which pushes the price up. Once enough people buy, the group sells into that demand. The price falls fast, and the late buyers are left with the losses."),
                    .paragraph("Small assets are used because it takes little money to move their price, and there may be few buyers when you want to sell."),
                    .heading("How to respond"),
                    .bullets([
                        "Don't act on urgency. Real opportunities survive a pause",
                        "Never send money to someone who offers to trade for you",
                        "Ignore support messages that arrive by DM",
                        "Report and block accounts that push these tactics"
                    ]),
                    .tip("Screenshots are easy to fake or edit. Treat them as claims, not proof.")
                ],
                takeaways: [
                    "Guaranteed returns and heavy urgency are major warning signs.",
                    "Pump-and-dumps target small, thinly traded assets that are easy to move.",
                    "Never send money to anyone who offers to manage it for you.",
                    "Report and block accounts that use scam tactics."
                ]
            ),
            LearnLesson(
                id: "communities-protect-account",
                title: "Protect your accounts",
                summary: "What never to share, and what to do if someone asks",
                minutes: 2,
                blocks: [
                    .paragraph("Your accounts are a target because they can lead to your money. Scammers often skip the market completely and simply try to get your login details. A few firm rules keep you safe."),
                    .heading("Never share these"),
                    .bullets([
                        "Passwords for Arkad, your email or your brokerage",
                        "Two-factor codes sent by text or an authenticator app",
                        "Crypto wallet seed phrases or private keys",
                        "Remote access to your phone, computer or brokerage account"
                    ]),
                    .paragraph("No genuine helper needs any of these. Anyone who has your seed phrase can move your crypto, and transfers usually can't be reversed."),
                    .heading("Arkad will never ask for your password"),
                    .paragraph("Arkad staff will never ask for your password or a verification code, in a DM or anywhere else. A message that asks is a scam, even if it uses the Arkad name or logo."),
                    .heading("If someone asks"),
                    .bullets([
                        "Don't reply with any details",
                        "Report the account and block it",
                        "If you shared something, change the password right away",
                        "Turn on two-factor authentication where you can"
                    ]),
                    .tip("Use a different password for every account. If one leaks, the others stay safe.")
                ],
                takeaways: [
                    "Never share passwords, 2FA codes, seed phrases or account access.",
                    "Arkad staff will never ask for your password.",
                    "Report and block anyone who asks for login details.",
                    "If you shared something by mistake, change it immediately."
                ]
            ),
            LearnLesson(
                id: "communities-past-results",
                title: "Past results don't guarantee anything",
                summary: "Survivorship bias, changing markets and what you're paying for",
                minutes: 2,
                blocks: [
                    .paragraph("A strong track record is encouraging, but it describes the past. It can't promise what happens next. Keeping that in mind protects you from overconfidence and from bad decisions."),
                    .heading("Survivorship bias"),
                    .paragraph("You mostly hear about traders who did well. Those who lost often stop posting or delete their accounts. That makes success look more common and more reliable than it really is."),
                    .heading("Markets change"),
                    .paragraph("A style that worked in a strong rising market may struggle when prices move sideways or fall. Volatility, interest rates and news all shift over time. A good past record doesn't mean the next month will look the same."),
                    .bullets([
                        "Check whether the record covers different market conditions",
                        "Expect losing periods, even from skilled traders",
                        "Keep your own risk rules no matter who you follow"
                    ]),
                    .heading("What a paid community gives you"),
                    .paragraph("Paying for a community buys access to ideas, education and discussion. It doesn't buy results. You still make every decision and carry every risk."),
                    .tip("Before joining a paid community, decide what you want to learn from it, not how much you hope to make.")
                ],
                takeaways: [
                    "A track record describes the past and can't promise the future.",
                    "Survivorship bias makes success look more common than it is.",
                    "Strategies that worked in one market may struggle in another.",
                    "A paid community gives you information, not guaranteed outcomes."
                ]
            )
        ],
        quiz: [
            LearnQuizQuestion(
                id: "communities-q1",
                prompt: "Which callout gives you the most to work with?",
                options: [
                    "Buy XYZ now, it's going to fly",
                    "XYZ, entry $20, stop $19, target $23, breakout on high volume, swing trade",
                    "XYZ is my favorite stock",
                    "Everyone is buying XYZ today"
                ],
                answerIndex: 1,
                explanation: "A clear callout includes an entry, stop, target, reasoning and timeframe, so you can check it and size it to your own risk."
            ),
            LearnQuizQuestion(
                id: "communities-q2",
                prompt: "A trader has 4 closed callouts, all winners. What can you conclude?",
                options: [
                    "They will keep winning",
                    "They are the best trader in the community",
                    "Not much yet, because the sample is too small",
                    "You should copy all their trades"
                ],
                answerIndex: 2,
                explanation: "A handful of results can easily come from luck. Many closed callouts across different conditions tell you much more."
            ),
            LearnQuizQuestion(
                id: "communities-q3",
                prompt: "Someone DMs you saying they're from Arkad support and need your password to fix your account. What should you do?",
                options: [
                    "Send it, since they're from support",
                    "Send only your two-factor code",
                    "Ask them to prove it first, then send it",
                    "Don't share anything, then report and block them"
                ],
                answerIndex: 3,
                explanation: "Arkad staff will never ask for your password or codes. Any message that does is a scam."
            ),
            LearnQuizQuestion(
                id: "communities-q4",
                prompt: "Why do pump-and-dump schemes usually target tiny, thinly traded coins or stocks?",
                options: [
                    "Their prices are easy to move with little money",
                    "They are regulated more strictly",
                    "They always go up over time",
                    "Large companies don't allow trading"
                ],
                answerIndex: 0,
                explanation: "Small, illiquid assets can be pushed up quickly, and there may be few buyers left when late buyers try to sell."
            ),
            LearnQuizQuestion(
                id: "communities-q5",
                prompt: "What does paying for a community actually buy you?",
                options: [
                    "Guaranteed profits",
                    "Access to ideas, education and discussion",
                    "Protection from losses",
                    "Someone else's responsibility for your trades"
                ],
                answerIndex: 1,
                explanation: "Past results don't guarantee future ones. You still make every decision and carry the risk."
            )
        ]
    )
}
