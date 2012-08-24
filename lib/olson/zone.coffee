
init = (helpers, rule, TimeZoneTime) ->

    # A Zone represents an Olson file line describing a steady state between two dates (or infinity for the last line of most zones)
    # and either a static time offset or set of rules to apply to determine the offset from "Local Time"
    class Zone
        constructor: (@name, @_offset, @_rule, @format, @_until, currZone) ->

            [isNegative, offsetHours, offsetMins, offsetSecs] = helpers.Time.ParseGMTOffset @_offset
            @offset = 
                negative: isNegative
                hours: offsetHours
                mins: offsetMins
                secs: if isNaN(offsetSecs) then 0 else offsetSecs

            begin = if currZone then helpers.Time.MakeDateFromTimeStamp(currZone.range.end.getTime() + 1) else helpers.Time.MinDate()
            @range =
                begin: begin
                end: @_parseUntilDate @_until

        _parseUntilDate: (til) ->
            # Doing the long parsing of the until field
            # Example: 1936 Mar 1 2:00
            # Example: 1883 Nov 18 12:14:48
            [year, monthName, day, time] = til.split " "
            [neg, h, mi, s] = if time then helpers.Time.ParseGMTOffset time else [false, 0, 0, 0]

            s = if isNaN(s) then 0 else s

            # return max date if we have no values
            return helpers.Time.MaxDate() if !year || year == ""

            # Otherwise, parse what we have
            year = parseInt year, 10
            month = if monthName then helpers.Months.MonthIndex monthName else 0
            day = if day then parseInt(day, 10) else 0

            # TODO: The end time here is standard, but there are situations where it should have a dst applied (australasia)

            standardTime = helpers.Time.StandardTimeToUTC @offset, year, month, day, h, mi, s
            # The end time is not inclusive, so back off by 1 millisecond
            endTime = helpers.Time.MakeDateFromTimeStamp(standardTime.getTime() - 1)

            return endTime

        UTCToWallTime: (dt, getRulesNamed) ->
            # Standard Time
            if @_rule == "-" or @_rule == ""
                # Apply the current offset, but no save.
                return new TimeZoneTime dt, @, helpers.noSave

            # Static Offset
            if @_rule.indexOf(":") >= 0
                # Add on the static savings and the offset
                [hours, mins] = helpers.Time.ParseTime @_rule
                return new TimeZoneTime dt, @, { hours: hours, mins: mins }

            # Applying a rule, which a rule set will do for us.
            rules = new rule.RuleSet((getRulesNamed @_rule), @)
            rules.getWallTimeForUTC dt

    class ZoneSet
        constructor: (@zones = [], @getRulesNamed) ->
            
            # Set a name from the passed in zones or default to ""
            if @zones.length > 0
                @name = @zones[0].name
            else 
                @name = ""

            # TODO: Does not check for consistent names on load?

        # Adds a zone to this sets collection
        add: (zone) ->
            # Update the name of the zone if this is the first zone we're adding
            if @zones.length == 0 and @name == ""
                @name = zone.name

            # Do not allow different named zones to be added
            if @name != zone.name
                throw new Error "Cannot add different named zones to a ZoneSet"

            # Add this zone to the current zones
            @zones.push zone

        findApplicable: (dt) ->
            ts = dt.getTime()
            found = null
            for zone in @zones
                if zone.range.begin.getTime() <= ts <= zone.range.end.getTime()
                    found = zone
                    break

            found

        getWallTimeForUTC: (dt) ->
            applicable = @findApplicable dt

            return new TimeZoneTime(dt, helpers.noZone, helpers.noSave) if not applicable

            applicable.UTCToWallTime dt, @getRulesNamed

    lib = 
        Zone: Zone
        ZoneSet: ZoneSet

if typeof window == 'undefined'
    req_helpers = require "./helpers"
    req_rule = require "./rule"
    req_TimeZoneTime = require "./timezonetime"
    module.exports = init(req_helpers, req_rule, req_TimeZoneTime)
else if typeof define != 'undefined'
    define ["olson/helpers", "olson/rule", "olson/TimeZoneTime"], init
else
    @.WallTime or= {}
    @.WallTime.zone = init(@.WallTime.helpers, @.WallTime.rule, @.WallTime.TimeZoneTime)
