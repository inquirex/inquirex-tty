Inquirex.define do
  start :do_you_have_a_minute

  confirm :do_you_have_a_minute do
    type :boolean
    question "Do you you have a few minutes to help us understand how you use the site, what's working and what needs fixing?"
    widget type: :toggle
    widget target: :mobile, type: :yes_no_buttons
    transition to: :name, if_rule: equals(:do_you_have_a_minute, true)
    transition to: :no_problem
  end

  ask :name do
    type :string
    question "What is your name? However you'd like to be called."
    widget type: :text_input
    widget target: :mobile, type: :text_input
    transition to: :email
  end

  ask :email do
    type :email
    question "Please share with us your email address so that we can notify you when your ideas and feedback has been put to good use."
    widget type: :email_input
    widget target: :mobile, type: :email_input
    transition to: :other_tools
  end

  say :no_problem do
    text "Not a problem. If you ever change your mind, just hit that round circle and answer the quesitons,. Adios!"
  end

  ask :other_tools do
    type :boolean
    question "Do you use any other online tools for generating laser cuts or engraving?"
    default false
    transition to: :uses_other_tools, if_rule: equals(:other_tools, true)
    transition to: :how_long_you_used_makeabox
  end

  ask :uses_other_tools do
    type :multi_enum
    question "May we ask which tools do you use to building enclosures cut with a laser cutter? If the tool you use is not listed, choose Unlisted."
    options i_dont: "I don't use Any of Them",
      makeabox: "MakeABox.io (this site)",
      makercase: "Makercase",
      boxes_py: "Boxes.py",
      www_atomm_com: "Atomm.com",
      vector_painter: "Vector Painter.com",
      laserbiz_ru: "Laserbiz.ru",
      hessmer_org_gears: "hessmer.org/gears",
      unlisted: "Unlisted (Other)"
    transition to: :makeabox_only, if_rule: contains(:uses_other_tools, "makeabox")
    transition to: :other, if_rule: contains(:uses_other_tools, "unlisted")
    transition to: :feedback
  end

  say :makeabox_only do
    text "Thanks for using MakeABox only :) We hope to improve this application futher and we appreciate your choice, considering there are a few out there :)"
    transition to: :how_long_you_used_makeabox
  end

  ask :how_long_you_used_makeabox do
    type :enum
    question "Give us a sense about how long have you been used MakeABox.io..."
    options first_time: "My First TIme",
      about_a_month: "About a Month",
      a_few_months: "A few Months",
      at_least_a_year: "At least a Year",
      over_a_year: "Over a Year",
      over_two_years: "Over two Years"
    default :first_time
    transition to: :other, if_rule: contains(:uses_other_tools, "unlisted")
    transition to: :feedback
  end

  ask :other do
    type :text
    widget type: :text_input
    question "Can you list the tools not listed in the previous question?"
    transition to: :feedback
  end

  ask :feedback do
    question "Pelase provide any feedback or bug reports that will make MakeABox.io better."
    type :text
    transition to: :thanks
  end

  say :thanks do
    text "We appreciate you taking the time to answer some of the questions! See you around!"
  end
end
