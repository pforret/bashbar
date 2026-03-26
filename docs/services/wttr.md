# chubin/wttr.in

## One-line output

One-line output format is convenient to be used to show weather info
in status bar of different programs, such as *tmux*, *weechat*, etc.

For one-line output format, specify additional URL parameter `format`:

```
$ curl wttr.in/Nuremberg?format=3
Nuremberg: 🌦 +11⁰C
```

Available preconfigured formats: 1, 2, 3, 4 and the custom format using the percent notation (see below).
* 1: Current weather at location: `🌦 +11⁰C`
* 2: Current weather at location with more details: `🌦   🌡️+11°C 🌬️↓4km/h`
* 3: Name of location and current weather at location: `Nuremberg: 🌦 +11⁰C`
* 4: Name of location and current weather at location with more details: `Nuremberg: 🌦   🌡️+11°C 🌬️↓4km/h`

You can specify multiple locations separated with `:` (for repeating queries):

```
$ curl wttr.in/Nuremberg:Hamburg:Berlin?format=3
Nuremberg: 🌦 +11⁰C
```
Or to process all this queries at once:

```
$ curl -s 'wttr.in/{Nuremberg,Hamburg,Berlin}?format=3'
Nuremberg: 🌦 +11⁰C
Hamburg: 🌦 +8⁰C
Berlin: 🌦 +8⁰C
```

To specify your own custom output format, use the special `%`-notation:

```
    c    Weather condition,
    C    Weather condition textual name,
    x    Weather condition, plain-text symbol,
    h    Humidity,
    t    Temperature (Actual),
    f    Temperature (Feels Like),
    w    Wind,
    l    Location,
    m    Moon phase 🌑🌒🌓🌔🌕🌖🌗🌘,
    M    Moon day,
    p    Precipitation (mm/3 hours),
    P    Pressure (hPa),
    e    Dew point,
    u    UV index (1-12),

    D    Dawn*,
    S    Sunrise*,
    z    Zenith*,
    s    Sunset*,
    d    Dusk*,
    T    Current time*,
    Z    Local timezone.

(*times are shown in the local timezone)
```

So, these two calls are the same:

```
    $ curl wttr.in/London?format=3
    London: ⛅️ +7⁰C
    $ curl wttr.in/London?format="%l:+%c+%t\n"
    London: ⛅️ +7⁰C
```

