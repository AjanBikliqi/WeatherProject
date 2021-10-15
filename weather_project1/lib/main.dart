import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:weather_project1/loading.dart';
import 'package:intl/intl.dart';

void main() => runApp(WeatherApp());

class WeatherApp extends StatefulWidget {
  @override
  _WeatherAppState createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  int temperature = 0;
  List minTemperatureForcast = List.filled(7, null, growable: false);
  List maxTemperatureForcast = List.filled(7, null, growable: false);
  String location = 'San Francisco';
  int woeid = 2487956;
  String weather = 'clear';
  String abbreviation = '';
  List abbrevationForcast = List.filled(7, null, growable: false);
  String errorMessage = '';
  bool loading = false;

  Position? _currentPosition;
  String? _currentAddress;

  String searchApiUrl =
      'https://www.metaweather.com/api/location/search/?query=';
  String locationApiUrl = 'https://www.metaweather.com/api/location/';

  initState() {
    super.initState();
    fetchLocation();
    fetchLocationDay();
  }

  Future<void> fetchSearch(String input) async {
    try {
      var searchResult = await http.get(Uri.parse(searchApiUrl + input));
      var result = json.decode(searchResult.body)[0];

      setState(() {
        location = result["title"];
        woeid = result["woeid"];
        errorMessage = '';
        loading = true;
      });
    } catch (error) {
      setState(() {
        errorMessage =
            "Sorry, we don't have data about this city. Try another one.";
        loading = false;
      });
    }
  }

  Future<void> fetchLocation() async {
    var locationResult =
        await http.get(Uri.parse(locationApiUrl + woeid.toString()));
    var result = json.decode(locationResult.body);
    var consolidated_weather = result["consolidated_weather"];
    var data = consolidated_weather[0];

    setState(() {
      temperature = data["the_temp"].round();
      weather = data["weather_state_name"].replaceAll(' ', '').toLowerCase();
      abbreviation = data["weather_state_abbr"];
      loading = false;
    });
  }

  Future<void> fetchLocationDay() async {
    var today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      var locationDayResult = await http.get(Uri.parse(locationApiUrl +
          woeid.toString() +
          '/' +
          DateFormat('y/M/d')
              .format(today.add(Duration(days: i + 1)))
              .toString()));
      var result = json.decode(locationDayResult.body);
      var data = result[0];

      setState(() {
        minTemperatureForcast[i] = data["min_temp"].round();
        maxTemperatureForcast[i] = data["max_temp"].round();
        abbrevationForcast[i] = data["weather_state_abbr"];
        loading = false;
      });
    }
  }

  Future<void> onTextFieldSubmitted(String input) async {
    await fetchSearch(input);
    await fetchLocation();
    await fetchLocationDay();
  }

  _getCurrentLocation() {
    Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .then((Position position) {
      setState(() {
        _currentPosition = position;
        _getAddressFromLatLng();
      });
    }).catchError((e) {
      print(e);
    });
  }

  _getAddressFromLatLng() async {
    // from latLng to actual location
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);

      Placemark place = placemarks[0];
      String? placeName = place.locality;
      print('Hello: $placeName');
      fetchSearch(placeName!);
      fetchLocation();

      setState(() {
        location = "${place.locality}";
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: loading
          ? Loading()
          : Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/$weather.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6),
                      BlendMode.dstATop), // makes the background darker
                ),
              ),
              child: temperature == null
                  ? Center(child: CircularProgressIndicator())
                  : Scaffold(
                      appBar: AppBar(
                        actions: <Widget>[
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 25.0, top: 20),
                            child: GestureDetector(
                              onTap: () {
                                _getCurrentLocation();
                              },
                              child: Icon(Icons.location_city, size: 36.0),
                            ),
                          ),
                        ],
                        backgroundColor: Colors.transparent,
                        elevation: 0.0,
                      ),
                      resizeToAvoidBottomInset: true,
                      backgroundColor: Colors.transparent,
                      body: SingleChildScrollView(
                        reverse: true,
                        padding: EdgeInsets.all(30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            if (_currentPosition != null)
                              if (_currentAddress != null)
                                Text(_currentAddress.toString()),
                            Column(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(
                                      right: 32.0, left: 32.0),
                                  child: Text(
                                    errorMessage,
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize:
                                            Platform.isAndroid ? 15.0 : 20.0),
                                            
                                  ),
                                ),
                                Center(
                                  child: Image.network(
                                    'https://www.metaweather.com/static/img/weather/png/' +
                                        abbreviation +
                                        '.png', 
                                    width: 110,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: Center(
                                    child: Text(
                                      errorMessage == ''
                                          ? temperature.toString() + ' °C'
                                          : '---',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 60.0),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      errorMessage == '' ? location : '---',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 40.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (errorMessage.isEmpty)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: <Widget>[
                                    for (var i = 0; i < 7; i++)
                                      forecastElement(
                                          i + 1,
                                          abbrevationForcast[i],
                                          minTemperatureForcast[i],
                                          maxTemperatureForcast[i]),
                                  ],
                                ),
                              ),
                            Column(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Container(
                                    width: 300,
                                    child: TextField(
                                      onSubmitted: (String input) {
                                        onTextFieldSubmitted(input);
                                      },
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 25),
                                      decoration: InputDecoration(
                                        hintText: 'Search a location...',
                                        hintStyle: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18.0),
                                        prefixIcon: Icon(Icons.search,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
    );
  }
}

Widget forecastElement(
    daysFromNow, abbreviation, minTemperature, maxTemperature) {
  var now = DateTime.now();
  var oneDayFromNow = now.add(Duration(days: daysFromNow));
  return Padding(
    padding: const EdgeInsets.only(left: 13.0),
    child: Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(205, 212, 228, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          children: <Widget>[
            Text(
              DateFormat.E().format(oneDayFromNow),
              style: TextStyle(color: Colors.white, fontSize: 25),
            ),
            Text(
              DateFormat.MMMd().format(oneDayFromNow),
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
              
              child: Image.network(
                'https://www.metaweather.com/static/img/weather/png/' +
                    abbreviation +
                    '.png' ,
                width: 50,
              ),
            ),
            Text(
              'Hight: ' + maxTemperature.toString() + ' °C',
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
            Text(
              'Low: ' + minTemperature.toString() + ' °C',
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
          ],
        ),
      ),
    ),
  );
}
 