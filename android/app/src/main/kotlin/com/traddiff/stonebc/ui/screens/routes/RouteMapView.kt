package com.traddiff.stonebc.ui.screens.routes

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.traddiff.stonebc.data.models.Route
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.plugins.annotation.LineManager
import org.maplibre.android.plugins.annotation.LineOptions
import org.maplibre.android.plugins.annotation.SymbolManager
import org.maplibre.android.plugins.annotation.SymbolOptions

private const val DEMO_STYLE_URL = "https://demotiles.maplibre.org/style.json"
private const val ROUTE_COLOR = "#2563EB"

@Composable
fun RouteMapView(route: Route, modifier: Modifier = Modifier, height: Dp = 240.dp) {
    val context = LocalContext.current
    val mapView = remember {
        MapLibre.getInstance(context)
        MapView(context).apply { onCreate(null) }
    }

    DisposableEffect(Unit) {
        mapView.onStart()
        mapView.onResume()
        mapView.getMapAsync { map ->
            map.setStyle(Style.Builder().fromUri(DEMO_STYLE_URL)) { style ->
                renderRoute(mapView, map, style, route)
            }
        }
        onDispose {
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }

    AndroidView(
        factory = { mapView },
        modifier = modifier
            .fillMaxWidth()
            .height(height)
    )
}

private fun renderRoute(
    mapView: MapView,
    map: MapLibreMap,
    style: Style,
    route: Route
) {
    val points = route.trackpoints.mapNotNull { pt ->
        val lat = pt.getOrNull(0) ?: return@mapNotNull null
        val lon = pt.getOrNull(1) ?: return@mapNotNull null
        LatLng(lat, lon)
    }

    if (points.size >= 2) {
        val lineManager = LineManager(mapView, map, style)
        lineManager.create(
            LineOptions()
                .withLatLngs(points)
                .withLineColor(ROUTE_COLOR)
                .withLineWidth(4f)
        )
    }

    val symbolManager = SymbolManager(mapView, map, style)
    symbolManager.create(
        SymbolOptions()
            .withLatLng(LatLng(route.startCoordinate.latitude, route.startCoordinate.longitude))
            .withTextField("Start")
            .withTextSize(11f)
    )

    fitCamera(map, route, points)
}

private fun fitCamera(map: MapLibreMap, route: Route, points: List<LatLng>) {
    if (points.isEmpty()) {
        map.moveCamera(
            CameraUpdateFactory.newLatLngZoom(
                LatLng(route.startCoordinate.latitude, route.startCoordinate.longitude),
                12.0
            )
        )
        return
    }
    val lats = points.map { it.latitude }
    val lons = points.map { it.longitude }
    val bounds = LatLngBounds.Builder()
        .include(LatLng(lats.min(), lons.min()))
        .include(LatLng(lats.max(), lons.max()))
        .build()
    map.moveCamera(CameraUpdateFactory.newLatLngBounds(bounds, 64))
}
