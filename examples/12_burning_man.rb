Inquirex.define do
  meta title: "Coolness Questionnaire",
    subtitle: "Let's figure out how cool you are :)"

  start :welcome

  say :welcome do
    text "Hello there! This is a demo of the Qualified.At DSL."
    transition to: :loves_to_dance
  end

  ask :loves_to_dance do
    type :boolean
    question "Might we ask, do you like to dance to electronic music?"
    transition to: :no_problem, if_rule: equals(:loves_to_dance, false)
    transition to: :burning_man
  end

  say :no_problem do
    text "Not everyone loves to dance. It's quite personal, we get it."
    transition to: :burning_man
  end

  ask :burning_man do
    type :enum
    question "How many times have you been to Burning Man?"
    options ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30"]
    transition to: :awesome, if_rule: greater_than(:burning_man, 20)
    transition to: :good, if_rule: greater_than(:burning_man, 10)
    transition to: :decent, if_rule: greater_than(:burning_man, 1)
    transition to: :lame, if_rule: less_than(:burning_man, 1)
    widget target: :tty, type: :select
    widget target: :desktop, type: :radio_group, columns: 5
    widget target: :mobile, type: :dropdown
  end

  say :awesome do
    text "You are awesome! That must be a record!"
  end

  say :good do
    text "Not bad at all! This is a very respectable number."
  end

  say :decent do
    text "It's decent, but not amazing, pardon our judgment :)"
  end

  say :lame do
    text "You've never been? Pardon the judgment, but you MUST go. It's beyond compare."
  end
end
