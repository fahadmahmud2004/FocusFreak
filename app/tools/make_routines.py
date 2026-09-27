#!/usr/bin/env python3
"""Generates the app's built-in routine catalogue from the FW Mentorship set.

    python3 tools/make_routines.py      # writes focusfreak_app/lib/domain/model/template_catalog.dart

The source is `fw_routines.json`, exported from FW Mentorship with every block
time already resolved by its seasonal engine: salah blocks sit on the season's
real clock, every day adds up to 1440 minutes, and each block starts exactly
where the one before it ends. Those times are the reason the routines are worth
porting, so nothing here moves one.

What this script adds is the bot. Every block the app ships must also be a
block the device can hold (`docs/PROTOCOL.md` §5, `ff_constants.dart`):

* a 16-character ASCII name and a 24-character description — the OLED font
  has no Bangla glyphs, so the copy is English, as the rest of the app is;
* one of six categories instead of FW's nine kinds.

The block *count* is left alone. FW's full days run 20–35 blocks and the bot
holds 16, but merging blocks to fit would delete the breaks between study
blocks — and a tracked block with a walk inside it breaks the moment you walk.
So the app keeps the whole day and hands the bot the next 16 blocks at a time
(`RoutineClock.deviceWindow`).

Edit the tables below and re-run; do not edit the generated Dart.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "fw_routines.json")
OUT = os.path.join(HERE, "..", "focusfreak_app", "lib", "domain", "model",
                   "template_catalog.dart")

NAME_MAX = 16
DESC_MAX = 24

# FW kind -> FocusFreak category (docs/PROTOCOL.md §11). `track` follows FW's
# "counts as study" flag.
KIND = {
    "deep": (0, True),
    "light": (1, True),
    "review": (2, True),
    "spiritual": (3, False),
    "meal": (3, False),
    "exercise": (3, False),
    "break": (4, False),
    "buffer": (4, False),
    "sleep": (5, False),
}

# A "sleep" block this short is a nap, and naps are category 4.
NAP_MAX_MIN = 120

# Bangla block text -> (name <=16, description <=24, overrides).
# Overrides: "cat" for a category FW's kind gets wrong for the bot, "track" for
# study that does not happen at the desk.
T = {
    "ব্রেক": ("Break", ""),
    "এশার সালাহ ও ডিনার": ("Isha & Dinner", "Salah, then dinner"),
    "জোহরের সালাহ, গোসল ও লাঞ্চ": ("Dhuhr & Lunch", "Salah, shower, lunch"),
    "আসরের সালাহ ও নাস্তা": ("Asr & Snack", ""),
    "ব্রেক, একটু হাঁটো": ("Walk Break", "Get up, walk a little"),
    "ওঠা, ফজরের সালাহ ও সকালের রুটিন": ("Wake & Fajr", "Fajr, water, sunlight"),
    "ঘড়ি ধরে MCQ": ("Timed MCQ", ""),
    "সবচেয়ে কঠিন সাবজেক্ট": ("Hardest Subject", "Fresh head, hard work"),
    "নাস্তা ও চা": ("Breakfast & Tea", ""),
    "মাগরিবের সালাহ ও নাস্তা": ("Maghrib & Snack", ""),
    "মাগরিবের সালাহ ও পরিবার": ("Maghrib & Family", ""),
    "আসরের সালাহ": ("Asr Salah", ""),
    "CQ আর অঙ্ক": ("CQ & Maths", "Explain it out loud"),
    "দ্বিতীয় সাবজেক্ট": ("Second Subject", ""),
    "পাওয়ার ন্যাপ": ("Power Nap", "20-30 min, no longer"),
    "মাগরিবের সালাহ": ("Maghrib Salah", ""),
    "দুর্বল টপিকগুলো": ("Weak Topics", ""),
    "বই বন্ধ করে মনে করো": ("Active Recall", "Book shut, recall it"),
    "একই চ্যাপ্টার চালিয়ে যাও": ("Same Chapter", "Keep going"),
    "অঙ্ক বা সমস্যা সমাধান": ("Problem Solving", "Maths or problems"),
    "ব্যায়াম বা হাঁটা": ("Exercise / Walk", ""),
    "একই সাবজেক্ট, বাকিটা শেষ করো": ("Same Subject", "Finish the rest"),
    "এবার অন্য সাবজেক্ট": ("Switch Subject", "Interleave"),
    "শেষ রিভিশন ও ভুলের খাতা": ("Final Revision", "+ mistake notebook"),
    "দিন শেষ, কালকের প্ল্যান লেখো": ("Plan Tomorrow", "Day done, write the plan"),
    "রিভিশন ও MCQ": ("Revision & MCQ", ""),
    "ব্রেক, উঠে দাঁড়াও": ("Stand-up Break", "Get off the chair"),
    "দুপুরের পড়া": ("Afternoon Study", ""),
    "কালকের প্ল্যান লিখে ঘুম": ("Plan & Bed", "Write tomorrow's plan"),
    "ফজরের সালাহ": ("Fajr Salah", ""),
    "হালকা নাস্তা": ("Light Snack", ""),
    "ফর্মুলা আর সংজ্ঞা, বই বন্ধ করে লেখো": ("Formula Recall", "Write them, book shut"),
    "ঘুমের প্রস্তুতি": ("Wind Down", "Get ready for bed"),
    "নোট আর থিওরি পড়া": ("Notes & Theory", ""),
    "রিভিশন": ("Revision", "Book shut, recall"),
    "ফজরের সালাহ ও কুরআন": ("Fajr & Quran", ""),
    "দিনের রিভিশন ও ফ্ল্যাশকার্ড": ("Day Revision", "+ flashcards"),
    "অঙ্ক প্র্যাকটিস": ("Maths Practice", ""),
    "একই সাবজেক্ট চালিয়ে যাও": ("Same Subject", "Keep going"),
    "তৃতীয় সাবজেক্ট": ("Third Subject", ""),
    "ব্রেক, টেবিল ছেড়ে একটু হাঁটো": ("Walk Break", "Leave the desk, walk"),
    "পাওয়ার ন্যাপ (২০–৩০ মিনিট)": ("Power Nap", "20-30 min, no longer"),
    "MCQ প্র্যাকটিস, ঘড়ি ধরে": ("Timed MCQ", "Beat the clock"),
    "আসরের সালাহ ও বিকেলের নাস্তা": ("Asr & Snack", ""),
    "আজকের পড়ার রিভিশন ও ফ্ল্যাশকার্ড": ("Today's Revision", "+ flashcards"),
    "তাহাজ্জুদ ও প্রস্তুতি": ("Tahajjud", "Salah, then get ready"),
    "সবচেয়ে কঠিন চ্যাপ্টার": ("Hardest Chapter", "The house is silent"),
    "নাস্তা ও রোদ": ("Breakfast & Sun", ""),
    "থিওরি ও নোট পড়া": ("Theory & Notes", ""),
    "নোট দেখা": ("Skim Notes", ""),
    "CQ প্র্যাকটিস": ("CQ Practice", ""),
    "ফ্রি টাইম ও পরিবার": ("Family Time", "Free time"),
    "শাটডাউন ও ঘুমের প্রস্তুতি": ("Shutdown", "Get ready for bed"),
    "ঘুম থেকে ওঠা, রোদ ও সকালের রুটিন": ("Wake & Sunlight", "Light first, then water"),
    "ব্রাঞ্চ / নাস্তা": ("Brunch", ""),
    "হালকা পড়া দিয়ে শুরু": ("Easy Start", "Light reading first"),
    "সাবজেক্ট বদলে পড়া": ("Switch Subject", "Interleave"),
    "পাওয়ার ন্যাপ, রাতের পড়ার আগে": ("Power Nap", "Before the night shift"),
    "হালকা নাস্তা, লাইট জ্বালিয়ে বসো": ("Snack & Lights", "Lights on, sit down"),
    "CQ ও বোর্ড প্রশ্ন": ("CQ & Board Qs", ""),
    "সাবজেক্ট মিশিয়ে রিভিশন": ("Mixed Revision", "Interleave subjects"),
    "বিশ্রাম, ওজু করে নাও": ("Rest & Wudu", ""),
    "ফজরের সালাহ, তারপর ঘুম": ("Fajr, then Sleep", ""),
    "ফ্ল্যাশকার্ড ও ভুলের খাতা": ("Flashcards", "+ mistake notebook"),
    "ক্লাসের আগে কঠিন সাবজেক্ট": ("Hard Subject", "Before class"),
    "আজ ক্লাসে যা পড়াবে, একবার চোখ বুলাও": ("Preview Class", "Skim today's lesson"),
    "নাস্তা ও তৈরি হওয়া": ("Breakfast", "Eat and get ready"),
    "যাতায়াত, সাথে ফ্ল্যাশকার্ড": ("Commute", "Flashcards on the way", {"cat": 3}),
    "কলেজ / কোচিং ক্লাস": ("College / Class", "Away from the desk", {"cat": 1}),
    "জোহরের সালাহ (কলেজেই)": ("Dhuhr at College", "", {"cat": 3}),
    "বাড়ি ফেরা, পথে ফ্ল্যাশকার্ড": ("Head Home", "Flashcards on the way", {"cat": 3}),
    "গোসল ও লাঞ্চ": ("Shower & Lunch", ""),
    "আজকের ক্লাসের নোট রিভিশন": ("Class Notes", "Revise today's class"),
    "নতুন চ্যাপ্টার": ("New Chapter", ""),
    "ফ্ল্যাশকার্ড": ("Flashcards", ""),
    "ওঠা, ওজু ও ফজরের সালাহ": ("Wake & Fajr", "Wudu, then salah"),
    "ব্রেক, চোখ বন্ধ করে বসো": ("Eyes-shut Break", "Sit, eyes closed"),
    "ব্রেক, মুখে পানি দাও": ("Splash Break", "Water on your face"),
    "দুপুরের পড়া চালিয়ে যাও": ("Afternoon Study", "Keep going"),
    "শেষ রিভিশন ও ফ্ল্যাশকার্ড": ("Final Revision", "+ flashcards"),
    "ওঠা ও ওজু": ("Wake & Wudu", ""),
    "দ্রুত নাস্তা": ("Quick Breakfast", ""),
    "CQ লেখা": ("Write CQ", ""),
    "আজকের টেস্টের চ্যাপ্টারগুলোয় চোখ বুলাও": ("Test Warm-up", "Skim today's chapters"),
    "ফর্মুলা শিট ও সংক্ষিপ্ত নোট": ("Formula Sheet", "+ short notes"),
    "আগের টেস্টগুলোর ভুলের খাতায় চোখ বুলাও": ("Past Mistakes", "From earlier tests"),
    "শ্বাস নাও, টেবিল গোছাও": ("Breathe & Tidy", "Clear the desk"),
    "চুপচাপ বসো, পরীক্ষার মুডে ঢোকো": ("Settle In", "Get into exam mode"),
    "মডেল টেস্ট, পুরো বোর্ডের নিয়মে": ("Model Test", "Full board rules"),
    "ন্যাপ, খাতা এখন দেখো না": ("Nap", "Don't mark it yet"),
    "নিজের খাতা নিজে দেখো, নম্বর দাও": ("Mark Your Paper", "Give yourself marks"),
    "ভুল প্রশ্নগুলো বই দেখে আবার সমাধান করো": ("Redo Mistakes", "Book open this time"),
    "প্রতিটা ভুলের কারণ ভুলের খাতায় লেখো": ("Log Mistakes", "Why each one went wrong"),
    "যেখানে ভুল হলো, সেই টপিক আবার পড়ো": ("Reread Topics", "Where you slipped"),
    "একই প্রশ্নগুলো আবার, এবার বই বন্ধ": ("Redo, Book Shut", "Same questions again"),
    "ওঠা, ফজরের সালাহ ও দোয়া": ("Wake, Fajr, Dua", ""),
    "ফর্মুলা শিট ও ভুলের খাতা": ("Formula Sheet", "+ mistake notebook"),
    "ব্রেক, ধীরে ধীরে শ্বাস নাও": ("Breathing Break", "Slow, deep breaths"),
    "শেষবার চোখ বুলাও, শুধু জানা জিনিস": ("Last Look", "Only what you know"),
    "ব্যাগ গোছানো": ("Pack Your Bag", ""),
    "রওনা দাও": ("Leave for Exam", ""),
    "হলে পৌঁছে শান্ত হও": ("Arrive & Settle", "Calm down at the hall"),
    "পরীক্ষা": ("Exam", "In the hall", {"track": False}),
    "জোহরের সালাহ, লাঞ্চ ও বাড়ি ফেরা": ("Dhuhr & Home", "Lunch, then head home"),
    "বিশ্রাম, উত্তর মেলাতে যেও না": ("Rest", "Don't check answers"),
    "একটু ঘুমিয়ে নাও": ("Short Sleep", ""),
    "পরের পরীক্ষার সিলেবাসে কী বাকি দেখে পড়া শুরু করো": ("Next Exam Plan", "What's left, then start"),
    "পরের পরীক্ষার কঠিন চ্যাপ্টার": ("Next: Hard Ch.", "Next paper's hardest"),
    "পরের পরীক্ষার রিভিশন": ("Next: Revision", ""),
    "ফর্মুলা ও ভুলের খাতা": ("Formulas", "+ mistake notebook"),
    "আজ তাড়াতাড়ি ঘুম": ("Early Night", ""),
    "সিলেবাসে কী কী বাকি দেখো": ("Syllabus Check", "What's still left"),
    "যেগুলো পারোনি, শুধু সেগুলো": ("Only the Misses", "Just what you missed"),
    "একই টপিক আবার, বই বন্ধ": ("Same Topic", "Again, book shut"),
    "ঘড়ি ধরে পুরো CQ লেখো": ("Timed Full CQ", ""),
    "CQ-র ভুলগুলো ভুলের খাতায় লেখো": ("Log CQ Mistakes", ""),
    "পরের দুর্বল টপিক": ("Next Weak Topic", ""),
    "দ্বিতীয় রাউন্ড: বই বন্ধ করে মনে করো": ("Recall Round 2", "Book shut"),
    "যেগুলো এখনো পারছ না": ("Still Stuck", "What you can't do yet"),
    "ঘড়ি ধরে CQ": ("Timed CQ", ""),
    "ভুলের খাতায় চোখ বুলাও": ("Mistake Notebook", ""),
    "কালকের লিস্ট লিখে ঘুম": ("List & Bed", "Write tomorrow's list"),
    "গতকালের পড়া, বই বন্ধ করে": ("Yesterday Recall", "Book shut"),
    "৩ দিন আগের পড়া": ("3 Days Ago", "Spaced review"),
    "৭ দিন আগের পড়া": ("7 Days Ago", "Spaced review"),
    "৩০ দিন আগের পড়া": ("30 Days Ago", "Spaced review"),
    "আজকের সব ফ্ল্যাশকার্ড": ("All Flashcards", "Today's deck"),
    "ভুলের খাতার বাকি ভুলগুলো ঠিক করো": ("Fix Mistakes", "Rest of the notebook"),
    "সব সাবজেক্ট মিশিয়ে MCQ": ("Mixed MCQ", "All subjects"),
    "দুর্বল সাবজেক্টের MCQ": ("Weak-subject MCQ", ""),
    "পুরোনো বোর্ড প্রশ্নের CQ": ("Old Board CQ", ""),
    "যেখানে আটকালে, সেই টপিক আবার পড়ো": ("Reread Topics", "Where you got stuck"),
    "আজকের রিভিশনে যেগুলো ভুল হলো, সেগুলো আবার": ("Redo Misses", "Today's wrong ones"),
    "নোট গুছিয়ে কালকের রিভিশন ঠিক করো": ("Sort Notes", "Set tomorrow's revision"),
    "এই সপ্তাহে কী কী বাকি পড়ে গেছে, লিস্ট করো": ("Backlog List", "What slipped this week"),
    "লিস্টের সবচেয়ে বড় বাকি কাজ": ("Biggest Backlog", "Top of the list"),
    "লিস্টের পরের বাকি কাজ": ("Next Backlog", ""),
    "যে চ্যাপ্টারটা আটকে ছিল, সেটা শেষ করো": ("Stuck Chapter", "Finish it today"),
    "সপ্তাহের বাকি থাকা MCQ ও CQ": ("Pending MCQ/CQ", "Left from the week"),
    "এই সপ্তাহের পড়া পুরোটা রিভিশন": ("Week Revision", "The whole week"),
    "সাপ্তাহিক টেস্ট, ঘড়ি ধরে": ("Weekly Test", "Timed"),
    "টেস্টের ভুলগুলো ঠিক করো, ভুলের খাতায় লেখো": ("Fix Test Errors", "Log them"),
    "এই সপ্তাহের ফ্ল্যাশকার্ড": ("Week Flashcards", ""),
    "সামনের সপ্তাহের প্রথম চ্যাপ্টারে চোখ বুলাও": ("Preview Next Wk", "Skim the first chapter"),
    "সামনের সপ্তাহের প্ল্যান লেখো": ("Plan Next Week", ""),
    "আবার একটু ঘুমিয়ে নাও": ("Sleep In", "A little more sleep"),
    "রোদে হাঁটা": ("Walk in the Sun", ""),
    "আরাম করে নাস্তা": ("Slow Breakfast", ""),
    "পড়ার টেবিল পরিষ্কার করো": ("Clean the Desk", ""),
    "শুধু নিজের নোটটা পড়ো": ("Your Own Notes", "Nothing new"),
    "শুধু আজকের ফ্ল্যাশকার্ড": ("Today's Cards", "Only today's"),
    "বই আর খাতা গোছাও": ("Sort Books", "Books and notebooks"),
    "ফ্রি টাইম, যা ভালো লাগে করো": ("Free Time", "Do what you enjoy"),
    "দুপুরের ঘুম": ("Afternoon Nap", ""),
    "যে চ্যাপ্টারটা তুমি ভালো পারো": ("Strong Chapter", "One you know well"),
    "ঘড়ি ছাড়া MCQ, কোনো চাপ নেই": ("Easy MCQ", "No clock, no pressure"),
    "মন হালকা করো": ("Unwind", ""),
    "এই সপ্তাহের সহজ টপিকগুলো রিভিশন": ("Easy Topics", "This week's easy ones"),
    "নতুন করে প্ল্যান করো": ("Fresh Plan", "Plan the week again"),
    "ফোন দূরে রাখো, তাড়াতাড়ি ঘুম": ("Early Night", "Phone away"),
    "ফ্রি টাইম বা ঘরের কাজ": ("Free Time", "Or chores"),
    "রাতের পড়া": ("Night Study", ""),
    "রাতের রিভিশন ও ভুলের খাতা": ("Night Revision", "+ mistake notebook"),
    "আরেকটা দুর্বল টপিক": ("Weak Topic 2", ""),
    "ভুলের খাতা থেকে ফ্ল্যাশকার্ড বানাও": ("Make Flashcards", "From your mistakes"),
    "সাহরি": ("Sehri", ""),
    "দোয়া ও প্রস্তুতি": ("Dua & Prepare", ""),
    "ফজরের পর কঠিন পড়া": ("Post-Fajr Study", "Hardest material"),
    "হালকা পড়া, নোট দেখা": ("Light Reading", "Skim your notes"),
    "জোহরের সালাহ ও কুরআন তিলাওয়াত": ("Dhuhr & Quran", ""),
    "রিভিশন, বই বন্ধ করে মনে করো": ("Recall Revision", "Book shut"),
    "বিশ্রাম ও পরিবার": ("Rest & Family", ""),
    "হালকা MCQ, ইফতারের আগে": ("Light MCQ", "Before iftar"),
    "ইফতার ও মাগরিবের সালাহ": ("Iftar & Maghrib", ""),
    "এশা ও তারাবীহ": ("Isha & Tarawih", ""),
    "তারাবীহর পর মন দিয়ে পড়া": ("Post-Tarawih", "Focused study"),
    "আজকের সব ভুল প্রশ্ন আবার": ("Redo Misses", "All of today's"),
    "ফ্ল্যাশকার্ড আরেকবার": ("Flashcards Again", ""),
    "সপ্তাহের ভুলের খাতায় শেষবার চোখ বুলাও": ("Week Mistakes", "One last look"),
    "ফ্ল্যাশকার্ড আরেকবার, ধীরে ধীরে": ("Flashcards Again", "Slowly"),
    "পরিবারের সাথে সময়": ("Family Time", ""),
    "ব্রেক, ফোন না দেখে চোখের বিশ্রাম": ("Eye Rest", "No phone"),
    "ব্রেক, কিছু খেয়ে নাও": ("Snack Break", ""),
    "তৃতীয় সাবজেক্ট বা দুর্বল টপিক": ("Third Subject", "Or a weak topic"),
    "আজ যা পড়লে তার রিভিশন": ("Today's Revision", ""),
    "খাওয়া, রোদ আর একটু হাঁটা": ("Eat & Walk", "Food, sun, a walk"),
    "লম্বা বিরতি ও পাওয়ার ন্যাপ": ("Long Break", "+ power nap"),
    "আজকের তিন সেশনের রিভিশন": ("Session Review", "All three sessions"),
    "লম্বা ব্রেক": ("Long Break", "Stand up, look far"),
    "পোমোডোরো ৮, আজ যা পড়লে তার রিভিশন": ("Pomodoro 8", "Review today"),
    "সেশন ৬, রিভিশন": ("Session 6", "Revision"),
}

BN_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")

# Routine-level English copy. Key order is the presentation order.
ROUTINES = {
    "standard": ("standard", "Standard",
                 "Not sure which to pick? Start here. Up for Fajr, asleep by "
                 "22:30, study built around the five salah."),
    "earlybird": ("earlyBird", "Early Bird",
                  "Up for tahajjud. The day's best study is done while the "
                  "house is silent."),
    "nightowl": ("nightOwl", "Night Owl",
                 "For people who study best at night. The day starts at noon, "
                 "the main study runs from Isha to Fajr, then sleep."),
    "collegeday": ("collegeDay", "College Day",
                   "Days with class. Your own study still fits around the "
                   "commute."),
    "hard16": ("hard16", "Hard Mode 16h",
               "16 hours of study, 5 of sleep. Right before exams, and no "
               "more than 7-10 days in a row."),
    "beast18": ("beast18", "Beast Mode 18h",
                "18 hours of study, 4 of sleep, barely a break. Only for the "
                "last 2-3 days before an exam."),
    "modeltest": ("modelTest", "Model Test Day",
                  "A full exam under board rules, 10:00-13:00. The rest of the "
                  "day is finding, logging and fixing your mistakes."),
    "examday": ("examDay", "Exam Day",
                "Exam 10:00-13:00. Nothing new in the morning. A short rest "
                "after, then the next paper. Seven hours of sleep."),
    "ramadan": ("ramadan", "Ramadan",
                "Built around sehri and iftar, so study keeps going while you "
                "fast."),
    "examcram": ("examCram", "Exam Cram",
                 "Exams are close. Short sessions and constant self-testing. "
                 "11 hours of study, 7 of sleep."),
    "revisionsprint": ("revisionSprint", "Revision Sprint",
                       "Nothing new today. Lock in what you read yesterday, 3, "
                       "7 and 30 days ago. 12 hours of study, 7 of sleep."),
    "weekenddive": ("weekendDive", "Weekend Deep Dive",
                    "Clear the week's backlog. Backlog in the morning, a "
                    "revision and a test after lunch, next week's plan at "
                    "night."),
    "recovery": ("recovery", "Recovery Day",
                 "Heavy head, fed up? Start fresh: full sleep, a tidy desk, a "
                 "new plan and five light hours of study."),
    "deepwork9020": ("deepWork", "Deep Work 90/20",
                     "90 minutes on, 20 off, five times. Starts the moment you "
                     "switch it on."),
    "ultradian3x90": ("ultradian", "Ultradian 3x90",
                      "Three 90-minute sessions with long breaks between. Less "
                      "time, full attention."),
    "pomodoro": ("pomodoro", "Pomodoro 25/5",
                 "25 on, 5 off, eight times, with one long break. For days you "
                 "can't make yourself sit down."),
    "fiftytwo17": ("fiftyTwo", "52/17",
                   "52 minutes on, 17 off. For work that needs a run-up."),
}

BASIS = {
    "clock": "Salah times follow Dhaka's season, so the day is built around "
             "them. Study runs in ~90-minute ultradian blocks with the hardest "
             "work first, and sleep is never cut below what memory "
             "consolidation needs.",
    "sequential": "Kleitman's basic rest-activity cycle: focus in blocks, "
                  "recover between them.",
}

SEASON_LABEL = {"summer": "", "winter": " (Winter)", "ramadan": ""}


def minutes(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def translate(block):
    text = block["text"]
    m = re.fullmatch(r"ঘুম(?: \((\d\d:\d\d)\))?", text)
    if m:
        return "Sleep", (f"Lights out {m.group(1)}" if m.group(1) else ""), {}
    m = re.fullmatch(r"(পোমোডোরো|সেশন) ([০-৯]+)", text)
    if m:
        word = "Pomodoro" if m.group(1) == "পোমোডোরো" else "Session"
        return f"{word} {m.group(2).translate(BN_DIGITS)}", "", {}
    if text not in T:
        sys.exit(f"no translation for block text: {text!r}")
    entry = T[text]
    return entry[0], entry[1], (entry[2] if len(entry) > 2 else {})


def to_block(b):
    name, desc, over = translate(b)
    cat, track = KIND[b["kind"]]
    if cat == 5 and b["durationMin"] < NAP_MAX_MIN:
        cat = 4
    cat = over.get("cat", cat)
    track = over.get("track", track)
    return {
        "name": name,
        "desc": desc,
        "dur": b["durationMin"],
        "cat": cat,
        "track": track,
        "start": minutes(b["time"]) if b.get("time") else None,
    }


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main():
    data = json.load(open(SRC, encoding="utf-8"))
    emitted = []
    problems = []

    order = list(ROUTINES)
    routines = sorted(
        data["routines"],
        key=lambda r: (order.index(r["id"].replace("-winter", "")),
                       r["id"].endswith("-winter")),
    )
    for r in routines:
        base = r["id"].replace("-winter", "")
        key, name, desc = ROUTINES[base]
        season = r.get("season")
        if season == "winter":
            key += "Winter"
        name += SEASON_LABEL.get(season, "")
        clock = r.get("modeHint") == "clock"

        blocks = [to_block(b) for b in r["blocks"]]
        if not clock:
            for b in blocks:
                b["start"] = None

        # The checks FW's verifyRoutines() runs, plus the bot's.
        if clock:
            total = sum(b["dur"] for b in blocks)
            if total != 1440:
                problems.append(f"{key}: day is {total} min")
            for a, b in zip(blocks, blocks[1:] + blocks[:1]):
                if (a["start"] + a["dur"]) % 1440 != b["start"]:
                    problems.append(f"{key}: gap after {a['name']}")
        for b in blocks:
            if len(b["name"]) > NAME_MAX or not b["name"].isascii():
                problems.append(f"{key}: name {b['name']!r}")
            if len(b["desc"]) > DESC_MAX or not b["desc"].isascii():
                problems.append(f"{key}: desc {b['desc']!r}")
        emitted.append((key, name, desc, season, clock, blocks))

    if problems:
        sys.exit("\n".join(problems))

    lines = [
        "// GENERATED by tools/make_routines.py from tools/fw_routines.json.",
        "// Do not edit by hand: change the script and re-run it.",
        "//",
        "// ignore_for_file: lines_longer_than_80_chars",
        "",
        "part of 'template.dart';",
        "",
        "const List<RoutineTemplate> _catalog = <RoutineTemplate>[",
    ]
    for key, name, desc, season, clock, blocks in emitted:
        lines.append("  RoutineTemplate(")
        lines.append(f"    key: {dart_str(key)},")
        lines.append(f"    name: {dart_str(name)},")
        lines.append(f"    description: {dart_str(desc)},")
        lines.append(f"    basis: {dart_str(BASIS['clock' if clock else 'sequential'])},")
        if season:
            lines.append(f"    season: RoutineSeason.{season},")
        lines.append("    blocks: <TemplateBlock>[")
        for b in blocks:
            args = [f"name: {dart_str(b['name'])}"]
            if b["desc"]:
                args.append(f"description: {dart_str(b['desc'])}")
            args.append(f"durationMin: {b['dur']}")
            args.append(f"category: {b['cat']}")
            if b["track"]:
                args.append("track: true")
            if b["start"] is not None:
                args.append(f"startMin: {b['start']}")
            lines.append(f"      TemplateBlock({', '.join(args)}),")
        lines.append("    ],")
        lines.append("  ),")
    lines.append("];")
    lines.append("")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    for key, _, _, season, _, blocks in emitted:
        print(f"{key:22} {season or '-':8} {len(blocks):2} blocks")
    print(f"wrote {os.path.relpath(OUT)}")


if __name__ == "__main__":
    main()
