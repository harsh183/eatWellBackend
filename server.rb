require 'sinatra'
require 'icalendar'
require 'pry'
require 'net/http'

# TODO: Consider the actual meal timings of all the dining halls (get it somehow from uiuc website)

class Utility
  def get_final_string
    "I've been expecting you"
  end
end

# Represents a single calendar event for the sake of our app
class StudentEvent
  attr_accessor :location, :start_time, :end_time, :summary, :until_date
  # TODO: Add support for one-time events

  def parse(event_from_ics)
    # Set all fields based on docs
    @location = event_from_ics.location
    @start_time = event_from_ics.dtstart.hour * 100 + event_from_ics.dtstart.minute
    @end_time = event_from_ics.dtend.hour * 100 + event_from_ics.dtend.minute
    @summary = event_from_ics.summary

    # TODO: Stop storing the timings as hhMM as int but as objects
  end
end

class DayEvents
  attr_accessor :student_events, :date

  def initialize(date)
    @student_events = []
    @date = date
  end
  
  def pick_out_given_days_events(all_events_list)
    all_events_list.each do |event|
      days = event.rrule[0].by_day
      current_week_day = convert_weekday_index_to_ics(date.now.strftime("%w").to_i) # Law of demeter
      if days.include? current_week_day # If event is given day add
        @student_events.push(event)
      end
    end

    @student_events.sort_by(&:start_time)
  end
end

# Represents the semester schedule 
class SemesterSchedule
  attr_accessor :schedule, :start_date, :end_date

  def init(start_date, end_date)
    @schedule = []
    @start_date = start_date
    @end_date = end_date
  end

  def add_new_day(events_of_day)
    @schedule.push(events_of_day)
  end
end

# Returns a days worth of meal timings
def find_meal_timings(day_events)
  # TODO: Remove hardcode of meal timings
  # TODO: Also todo, stop using hh:mm number
  # TODO: Make this into another object
  # TODO: Account for customizable meal timings (I'm guessing chop off the unwanted meals)
  meals = %w(Breakfast Lunch Dinner)
  timings = [[700, 1030], [1030, 1500], []]
end

def convert_weekday_index_to_ics(weekday_id)
  mapping = %w{MO TU WE TH FR SA SU}
  mapping[weekday_id]
end

def query_walking_distance(place1, place2)
  # TODO: Implement cache
  # TODO: Remove room no from both
  base_url = "https://walk-time-calculator.herokuapp.com"
  full_url = base_url + "/#{place1};#{place2}"
  uri = URI(full_url)
  Net::HTTP.get(uri)
end

# For now just be a thin wrapper to java
#get '/' do
  file = File.open('Fall 2018 - Urbana-Champaign.ics')
  # Open a file or pass a string to the parse
  cals = Icalendar::Calendar.parse(file)
  cal = cals.first
  events = cal.events

  # TODO: Un-hardcode it
  start_date = Date.new(2018,8,29)
  end_date = Date.new(2018,12,12)

  # Look from start to end
  current_date = start_date
  while end_date >= current_date
    # Exclude weekends
    unless current_date.saturday? || current_date.sunday?
    	# puts current_date

    	# Add events
      day_events = DayEvents.new(current_date)
      day_events.pick_out_given_days_events(events)
    
    	# Find meal timings
    	# Get locations and walking distances
    	# TODO: Make sure to cache things to reduce load on server

    	# Save them
    end
    current_date = current_date.next_day
  end

  # Write them onto an ics file
  # By looping through each 

  events.each do |event|
    puts "location #{event.location}"
    puts "rrule #{event.rrule[0].by_day}"
    puts "start date-time timezone: #{event.dtstart.ical_params['tzid']}"
    puts "summary: #{event.summary}"
  end
  
  Utility.new.get_final_string
#end
