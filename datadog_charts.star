"""
Applet: DataDog Charts
Summary: View your DataDog Dashboard Charts
Description: By default, displays the first chart on your DataDog dashboard.
Author: Gabe Ochoa
"""

load("animation.star", "animation")
load("cache.star", "cache")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")


CACHE_KEY_PREFIX = "charts_cached"
DEFAULT_QUERY = "status:alert"
DEFAULT_APP_KEY = ""
DEFAULT_API_KEY = ""

def main(config):
    DD_API_KEY = config.get("api_key") or DEFAULT_API_KEY
    DD_APP_KEY = config.get("app_key") or DEFAULT_APP_KEY

    if DD_API_KEY == None or DD_APP_KEY == None:
        child = render.Row(
            cross_align = "center",
            main_align = "center",
            children = [
                render.WrappedText(align = "center", content = "DataDog API Key or App Key not set."),
            ],
        ) 
        return render.Root(child = child)

    CACHE_KEY = "{}-{}-{}".format(CACHE_KEY_PREFIX, DD_API_KEY, DD_APP_KEY)
    charts_query = config.str("custom_query", DEFAULT_QUERY)

    charts_cached = cache.get(CACHE_KEY)

    dashboard_json = http.get(
        "https://api.datadoghq.com/api/v1/dashboard/jdg-eeu-eyd",
        headers = {"DD-API-KEY": DD_API_KEY, "DD-APPLICATION-KEY": DD_APP_KEY, "Accept": "application/json"},
    ).json()

    print(dashboard_json)

    if dashboard_json.get("errors") != None:
        child = render.Row(
            cross_align = "center",
            main_align = "center",
            children = [
                render.WrappedText(content = dashboard_json.get("errors")[0]),
            ],
        ) 
        return render.Root(child = child)

    first_widget = dashboard_json.get("widgets")[0]
    query = first_widget.get("definition").get("requests")[0].get("fill").get("q")

    # Query metrics API to get the list of points to plot
    from_time = time.now().unix-60
    to_time = time.now().unix
    data = http.get(
        "https://api.datadoghq.com/api/v1/query",
        params = {"from": from_time, "to": to_time, "query": query},
        headers = {"DD-API-KEY": DD_API_KEY, "DD-APPLICATION-KEY": DD_APP_KEY, "Accept": "application/json"},
    ).json()


    # TODO: Determine if this cache call can be converted to the new HTTP cache.
    cache.set(CACHE_KEY, data, ttl_seconds = 240)
    
    plot = create_plot(data.get("series")[0].get("pointlist"))

    child = render.Row(
        expanded = True,
        cross_align = "center",
        main_align = "center",
        children = [
            render.Text(content = "No issues!"),
        ],
    )

    if len(plot) > 0:
        child = render.Plot(
            title = "DataDog Chart",
            x_label = "Time",
            y_label = "Query Count",
            data = plot,
        )

    return render.Root(child = child)


def create_plot(datapoints):
    """
    Generates plot data from supplied datapoints

    Args:
        datapoints: list of floats

    Returns:
        list of tuples (index, datapoint_to_display)
    """
    plot = []
    index = 0

    for query_ct in datapoints:
        plot.append((index, query_ct))
        index += 1

    return plot