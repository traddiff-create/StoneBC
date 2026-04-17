package com.traddiff.stonebc.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.traddiff.stonebc.ui.screens.BikesScreen
import com.traddiff.stonebc.ui.screens.MoreScreen
import com.traddiff.stonebc.ui.screens.home.HomeScreen
import com.traddiff.stonebc.ui.screens.record.RecordScreen
import com.traddiff.stonebc.ui.screens.routes.RouteDetailScreen
import com.traddiff.stonebc.ui.screens.routes.RoutesScreen

enum class Tab(val route: String, val label: String, val icon: ImageVector) {
    Home("home", "Home", Icons.Default.Home),
    Routes("routes", "Routes", Icons.Default.Map),
    Record("record", "Record", Icons.Default.FiberManualRecord),
    Bikes("bikes", "Bikes", Icons.AutoMirrored.Filled.DirectionsBike),
    More("more", "More", Icons.Default.MoreHoriz)
}

private const val ROUTE_DETAIL_ARG = "routeId"
private const val ROUTE_DETAIL_TEMPLATE = "route_detail/{$ROUTE_DETAIL_ARG}"
private fun routeDetailRoute(id: String) = "route_detail/$id"

@Composable
fun MainNavHost() {
    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            val currentBackStack by navController.currentBackStackEntryAsState()
            val currentRoute = currentBackStack?.destination?.route

            NavigationBar {
                Tab.entries.forEach { tab ->
                    val selected = currentRoute == tab.route ||
                        currentRoute?.startsWith("${tab.route}/") == true ||
                        (tab == Tab.Routes && currentRoute?.startsWith("route_detail/") == true)
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Tab.Home.route,
            modifier = Modifier.padding(padding)
        ) {
            composable(Tab.Home.route) { HomeScreen() }
            composable(Tab.Routes.route) {
                RoutesScreen(onRouteTap = { id -> navController.navigate(routeDetailRoute(id)) })
            }
            composable(
                route = ROUTE_DETAIL_TEMPLATE,
                arguments = listOf(navArgument(ROUTE_DETAIL_ARG) { type = NavType.StringType })
            ) { entry ->
                val routeId = entry.arguments?.getString(ROUTE_DETAIL_ARG).orEmpty()
                RouteDetailScreen(routeId = routeId, onBack = { navController.popBackStack() })
            }
            composable(Tab.Record.route) { RecordScreen() }
            composable(Tab.Bikes.route) { BikesScreen() }
            composable(Tab.More.route) { MoreScreen() }
        }
    }
}
