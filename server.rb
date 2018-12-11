require 'sinatra'
require 'icalendar'
require 'pry'
require 'net/http'
require 'json'

$distance_cache = {} # Store the results so that we don't end up hitting the server again and again

# TODO: See if it's possible to split this into multiple files
# TODO: Consider the actual meal timings of all the dining halls (get it somehow from uiuc website)
# TODO: Put all the meal scheduling things onto their own module or class
# TODO: Make variables consistent
# TODO: Make code less tightly coupled

# TODO: Also make a more simplified route that just gets it for a single days worth of events

class Utility
  def get_final_string
    "Execute order 66" # TODO: Placeholder for now, put some other status thing later
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

  def timing_within_event?(timing)
    @start_time < timing && timing < @end_time
  end

  def duration
    (@end_time / 100 - @start_time / 100) * 60 + (@end_time % 100 - @start_time % 100)
  end

  def to_s
    "#{@summary} at #{@location} from #{@start_time} to #{@end_time}"
  end
end

# Represents a day of events alongside a date.
class DayEvents
  attr_accessor :student_events, :date

  def initialize(date)
    @student_events = []
    @date = date
  end
  
  def pick_out_given_days_events(all_events_list)
    all_events_list.each do |event|
      days = event.rrule[0].by_day
      current_week_day = convert_weekday_index_to_ics(date.strftime("%w").to_i) # TODO: Law of demeter
      if days.include? current_week_day # If event is given day add
        parsed_event = StudentEvent.new
        parsed_event.parse(event)
        @student_events.push(parsed_event)
      end
    end
    @student_events = @student_events.sort_by {|event| event.start_time}
  end
end

# Represents the semester schedule 
class SemesterSchedule
  attr_accessor :schedule, :start_date, :end_date

  def initialize(start_date, end_date)
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
  # MAHA TODO: Account for customizable meal timings (I'm guessing chop off the unwanted meals)
  meals = %w(Breakfast Lunch Dinner)
  timings = [[700, 1030], [1030, 1500], [1600, 2000]]

  meals_for_day = []
  timings.each_with_index do |timing, index|
    possible_intervals = get_intervals_in_range(day_events, timing[0], timing[1])
    puts "Possible intervals: #{possible_intervals.length}"

    # TODO: Move get right interval into it's own function
    # Find the largest meal timing or first one that's 2 hours in length
    meal_timing = possible_intervals[0]
    possible_intervals.each do |interval|
      duration = interval.duration
      puts "Possible: #{meal_timing} at #{duration}"
      if duration >= 120
        meal_timing = interval
        meal_timing.end_time = meal_timing.start_time + 200
        break
      elsif duration > meal_timing.duration
        meal_timing = interval
      end
    end

    meal_timing.summary = meals[index]
    before_hall = find_location_before(meal_timing.start_time, day_events)
    after_hall = find_location_after(meal_timing.end_time, day_events)
    puts meal_timing
    # puts "Before hall #{before_hall}, after hall #{after_hall}"
    meal_timing.location = find_dining_hall_with_least_walking_time(before_hall, after_hall)
    meals_for_day.push meal_timing
  end

  return meals_for_day
end

def get_intervals_in_range(day_events, start_point, end_point)
  # TODO: This function is pretty long - Cleanup this logic sometime DRY and simplify a little
  # TODO: Remove the * 1
  # Note that this is basically like a sorta inversion, so expect code to be something like that
  intervals = []

  # Find true starting point
  day_events.student_events.each do |event|
    start_point = event.end_time * 1 if event.timing_within_event? start_point
  end
  puts "For #{start_point} to #{end_point}"
  interval = StudentEvent.new
  interval.start_time = start_point * 1

  #puts "The start point is #{start_point} and end point #{end_point}"
  # Loop through the rest
  found_first_event = false
  #puts "#{day_events.student_events.length} events being considered here"
  day_events.student_events.each do |event|
    #puts "Consider #{event}"
    if event.end_time < end_point && event.start_time > start_point
      # puts "Do we ever get here"
      found_first_event = true
      interval.end_time = event.start_time * 1
      intervals.push interval
      interval = StudentEvent.new
      interval.start_time = event.end_time * 1
    elsif found_first_event
      break
    end
  end

  # Find true ending point
  # TODO: Simplify this block (I think the if case is unneeded)
  if found_first_event
    day_events.student_events.each do |event|
      if event.timing_within_event? end_point
        end_point = event.start_time * 1
      end
    end
    interval.end_time = end_point * 1
    intervals.push interval
  else
    interval = StudentEvent.new
    interval.start_time = start_point * 1
    interval.end_time = end_point * 1
    intervals.push interval
  end

  return intervals
end

def convert_weekday_index_to_ics(weekday_id)
  mapping = %w{SU MO TU WE TH FR SA}
  mapping[weekday_id]
end

# TODO: The next two functions are a little hacky (well what isn't) but fix them (maybe store these at time of creator)
def find_location_before(time, day_events)
  location_before = "" # Placeholder
  min_diffence = 120 # Placeholder
  day_events.student_events.each do |event|
    difference = time - event.end_time
    if difference > 0
      if (difference < min_diffence)
        min_diffence = difference
        location_before = event.location
      end
    end
  end

  location_before
end

def find_location_after(time, day_events)
  location_after = "" # Placeholder
  min_diffence = 120 # Placeholder
  day_events.student_events.each do |event|
    difference = event.start_time - time
    if difference > 0
      if (difference < min_diffence)
        min_diffence = difference
        location_after = event.location
      end
    end
  end

  location_after
end

def find_dining_hall_with_least_walking_time(location_before, location_after)
  # TODO: Make dining halls adjustable
  dining_halls = ["Florida Avenue (FAR) Dining Hall",
                  "Illini Union",
                  "Lincoln Avenue (LAR) Dining Hall",
                  "Ikenberry Dining Center SDRP",
                  "Pennsylvania Avenue (PAR) Dining Hall"]
  min_time = 120 # Some large value TODO: This is terrible code
  least_walking_hall = "University dining" # Placeholder value
  dining_halls.each do |hall|
    time = 0
    time += query_walking_distance(location_before, hall) unless location_before.empty?
    time += query_walking_distance(location_after, hall) unless location_after.empty?

    if time < min_time
      least_walking_hall = hall
      min_time = time
    end
  end

  return least_walking_hall
end

def query_walking_distance(place1, place2)
  # Remove part after room for both
  place1 = place1.split("Room:")[0].gsub(" ", "+")
  place2 = place2.split("Room:")[0].gsub(" ", "+")

  # Check if it exists in the cache (the hash), otherwise do a request TODO: Move this to it's own block
  place_pair = "/#{place1};#{place2}"
  place_pair2 = "/#{place2};#{place1}"
  if $distance_cache.has_key? place_pair
    return $distance_cache[place_pair]
  elsif $distance_cache.has_key? place_pair2
    return $distance_cache[place_pair2]
  else
    base_url = "https://walk-time-calculator.herokuapp.com"
    full_url = base_url + place_pair
    uri = URI(full_url)
    result = Net::HTTP.get(uri).to_f
    $distance_cache[place_pair] = result
    return result
  end
end

# Returns a string representing an ics
def convert_to_ics(semester_schedule)
  # TODO: Check if the ics actually has all the expected events
  cal = Icalendar::Calendar.new
  cal.timezone do |t|
    t.tzid = "America/Chicago"

    t.daylight do |d|
      d.tzoffsetfrom = "-0600"
      d.tzoffsetto   = "-0500"
      d.tzname       = "CDT"
      d.dtstart      = "19700308T020000"
      d.rrule        = "FREQ=YEARLY;BYMONTH=3;BYDAY=2SU"
    end

    t.standard do |s|
      s.tzoffsetfrom = "-0500"
      s.tzoffsetto   = "-0600"
      s.tzname       = "CST"
      s.dtstart      = "19701101T020000"
      s.rrule        = "FREQ=YEARLY;BYMONTH=11;BYDAY=1SU"
    end
  end

  days = semester_schedule.schedule
  days.each do |day|
    dateObject = day.date
    day.student_events.each do |event|
      date = dateObject.strftime("%Y%m%d")
      cal.event do |e|
        start_date_time = dateObject.to_time #(date + event.start_time.to_s).to_i
        start_date_time = start_date_time + (event.start_time / 100) * 3600 + (event.start_time % 100) * 60
        e.dtstart     = Icalendar::Values::DateOrDateTime.new(start_date_time)

        end_date_time = dateObject.to_time #(date + event.start_time.to_s).to_i
        end_date_time = end_date_time + (event.end_time / 100) * 3600 + (event.end_time % 100) * 60
        e.dtend       = Icalendar::Values::DateOrDateTime.new(end_date_time)
        e.summary     = event.summary
        e.location    = event.location
        e.description = "Have a nice and wholesome meal!"
      end
    end
  end

  cal.publish
  cal
  return cal.to_ical
end

get '/' do
  content_type :json
  $distance_cache = {} # Store the results so that we don't end up hitting the server again and again

  file = File.open('Fall 2018 - Urbana-Champaign.ics') # MAHA TODO: Take file input
  # Open a file or pass a string to the parse
  cals = Icalendar::Calendar.parse(file)
  cal = cals.first
  events = cal.events

  # TODO: Un-hardcode ithar
  start_date = Date.new(2018,8,29)
  end_date = Date.new(2018,12,12) # should be 2018,12,12

  schedule = SemesterSchedule.new(start_date, end_date)

  # Look from start to end
  current_date = start_date
  while end_date >= current_date
    # Exclude weekends
    unless current_date.saturday? || current_date.sunday?
      puts
      puts current_date
      day_events = DayEvents.new(current_date)
      day_events.pick_out_given_days_events(events)

      # puts "Day has #{day_events.student_events.length} events"
      day_events.student_events.each do |event|
        # puts event
      end

      meal_timings = find_meal_timings(day_events)
      day_events.student_events = meal_timings
      schedule.add_new_day(day_events)
    end
    current_date = current_date.next_day
  end

  ical_file = convert_to_ics(schedule)
  # MAHA TODO: Return this back to use

  # puts ical_file
  hash = { result: ical_file}
  hash.to_json
  # Utility.new.get_final_string
end

# MAHA TODO: Fix the time crossing bug (similar to java)
# MAHA TODO: Deploy to prod