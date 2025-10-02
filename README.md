# CoffeeAddicts
## Overview
You have been hired by a company that builds an app for coffee addicts. You are
responsible for writing a REST API that offers the possibility to take the user&#39;s
coordinates and return a list of the three closest coffee shops (including distance
from the user) in order from the closest to farthest.
Data
The coffee shops are stored in a remote CSV having these columns: Name,X,Y
The quality of data in this list of coffee shops may vary. Malformed entries should be
handled appropriately.
Notice that the data file will be read from a network location (ex:
https://static.reasig.ro/interview/coffee_shops_exerceise/coffee_shops.csv )
## API Response
A list of the three closest coffee shops (name, location and distance from the user)
in order from the closest to farthest.
These distances should be rounded to four decimal places.
Assume all coordinates lie on a plane.
## Example
For the provided coordinates X=47.6 and Y=-122.4 the response should contain
these coffee shops:
- Starbucks Seattle2
- Starbucks Seattle
- Starbucks SF
