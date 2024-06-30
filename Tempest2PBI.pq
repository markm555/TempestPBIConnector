// This file contains your Data Connector logic
[Version = "1.0.0"]
section Tempest2PBI;

[DataSource.Kind="Tempest2PBI", Publish="Tempest2PBI.Publish"]
shared EnterData = (DeviceID as text, Key as text, StartDaysBack as number, EndDaysBack as number, TimeZone as text) =>

let
    //DeviceID = "<Your Device ID",
    //Key = "<Your Key>",
    //TimeZone = "-5",
    timeZoneOffset = Number.FromText(TimeZone),
    sign = if timeZoneOffset < 0 then -1 else 1,  
    // Create a list of days for which we want to fetch the data
    daysList = List.Numbers(StartDaysBack, EndDaysBack),  // ** Change this line ** – the 0 is the start day and the 10 is the end day in this case I start with today (0) and go back 10 days (9)
    // Function to fetch data for a single day
    fetchDataForDay = (day as number) as table =>
        let
            // Make the API call for the current day
            apiResponse = Web.Contents("https://swd.weatherflow.com/swd/rest/observations/device/" & DeviceID & "?day_offset=" & Text.From(day) & "&token=" & Key),
            // Parse the JSON results
            parsedJson = Json.Document(apiResponse),
            // Check if 'obs' is null and process accordingly
            fahrenheitTable = if parsedJson[obs] <> null then 
                let
                    // Extract the JArray
                    jsonArray = parsedJson[obs],
                    // Convert the JArray into a table
                    outputTable = Table.FromList(jsonArray, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                    recordsTable = Table.TransformColumns(outputTable, {"Column1", each Record.FromList(_, {
                        "epoch", 
                        "wind_lull",
                        "wind_avg" ,
                        "wind_gust",
                        "wind_dir",
                        "wind_smpl",
                        "pressure",
                        "temp",
                        "humidity",
                        "illuminance",
                        "UV",
                        "soloar_radiation",
                        "rain_acc",
                        "precity_type",
                        "avg_strike_dist",
                        "strike_cnt",
                        "battery",
                        "rep_int",
                        "day_rain",
                        "nc_rain",
                        "nc_day_rain",
                        "precipt_analysis"}), type record}),
                    expandedTable = Table.ExpandRecordColumn(recordsTable, "Column1", {
                        "epoch", 
                        "wind_lull",
                        "wind_avg" ,
                        "wind_gust",
                        "wind_dir",
                        "wind_smpl",
                        "pressure",
                        "temp",
                        "humidity",
                        "illuminance",
                        "UV",
                        "soloar_radiation",
                        "rain_acc",
                        "precity_type",
                        "avg_strike_dist",
                        "strike_cnt",
                        "battery",
                        "rep_int",
                        "day_rain",
                        "nc_rain",
                        "nc_day_rain",
                        "precipt_analysis"}),
                    // Convert epoch from a unix time stamp to DateTime
                    //dateTimeTable = Table.TransformColumns(expandedTable, {"epoch", each #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, _), type datetime}),
                    dateTimeTable = Table.TransformColumns(expandedTable, {"epoch", each #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, _) - #duration(0, sign * timeZoneOffset, 0, 0), type datetime}),
                    // Convert temp from C to F.
                    fahrenheitTable = Table.TransformColumns(dateTimeTable, {"temp", each _ * 9/5 + 32, type number}),
                    // Convert rain_acc from mm to inches
                    rainAccInchesTable = Table.TransformColumns(fahrenheitTable, {"rain_acc", each _ * 0.0393701, type number}),
                    // Convert avg_strike_dist from km to miles
                    avgStrikeDistMilesTable = Table.TransformColumns(rainAccInchesTable, {"avg_strike_dist", each _ * 0.621371, type number}),
                    // Convert day_rain from mm to inches
                    dayRainInchesTable = Table.TransformColumns(avgStrikeDistMilesTable, {"day_rain", each _ * 0.0393701, type number}),
                    // Convert nc_rain from mm to inches
                    ncRainInchesTable = Table.TransformColumns(dayRainInchesTable, {"nc_rain", each _ * 0.0393701, type number}),
                    // Convert nc_day_rain from mm to inches
                    ncDayRainInchesTable = Table.TransformColumns(ncRainInchesTable, {"nc_day_rain", each _ * 0.0393701, type number})
                in
                    ncDayRainInchesTable
            else
                #table(type table [epoch=datetime, wind_lull=number, wind_avg=number, wind_gust=number, wind_dir=number, wind_smpl=number, pressure=number, temp=number, humidity=number, illuminance=number, UV=number, soloar_radiation=number, rain_acc=number, precity_type=number, avg_strike_dist=number, strike_cnt=number, battery=number, rep_int=number, day_rain=number, nc_rain=number, nc_day_rain=number, precipt_analysis=number], {})
        in
            fahrenheitTable,
    // Fetch data for all days and combine into a single table
    allData = Table.Combine(List.Transform(daysList, each fetchDataForDay(_)))
in
    allData;

// Data Source Kind description
Tempest2PBI = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
Tempest2PBI.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Tempest2PBI.Icons,
    SourceTypeImage = Tempest2PBI.Icons
];

Tempest2PBI.Icons = [
    Icon16 = { Extension.Contents("Tempest2PBI16.png"), Extension.Contents("Tempest2PBI20.png"), Extension.Contents("Tempest2PBI24.png"), Extension.Contents("Tempest2PBI32.png") },
    Icon32 = { Extension.Contents("Tempest2PBI32.png"), Extension.Contents("Tempest2PBI40.png"), Extension.Contents("Tempest2PBI48.png"), Extension.Contents("Tempest2PBI64.png") }
];
