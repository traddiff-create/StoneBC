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
import com.traddiff.stonebc.ui.screens.bikes.BikeDetailScreen
import com.traddiff.stonebc.ui.screens.bikes.BikesScreen
import com.traddiff.stonebc.ui.screens.expedition.ExpeditionCaptureScreen
import com.traddiff.stonebc.ui.screens.expedition.ExpeditionDetailScreen
import com.traddiff.stonebc.ui.screens.expedition.ExpeditionListScreen
import com.traddiff.stonebc.ui.screens.expedition.ExpeditionNewScreen
import com.traddiff.stonebc.ui.screens.home.HomeScreen
import com.traddiff.stonebc.ui.screens.more.CommunityFeedScreen
import com.traddiff.stonebc.ui.screens.more.DonateScreen
import com.traddiff.stonebc.ui.screens.more.EventsScreen
import com.traddiff.stonebc.ui.screens.more.GalleryScreen
import com.traddiff.stonebc.ui.screens.more.MoreScreen
import com.traddiff.stonebc.ui.screens.more.ProgramsScreen
import com.traddiff.stonebc.ui.screens.more.SwissArmyKnifeScreen
import com.traddiff.stonebc.ui.screens.more.TourGuidesScreen
import com.traddiff.stonebc.ui.screens.more.VolunteerScreen
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

private const val ROUTE_DETAIL_TEMPLATE = "route_detail/{routeId}"
private const val BIKE_DETAIL_TEMPLATE = "bike_detail/{bikeId}"

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
                        currentRoute?.startsWith("${tab.route}_") == true ||
                        isInTabFamily(tab, currentRoute)
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
            composable(Tab.Record.route) { RecordScreen() }

            composable(Tab.Routes.route) {
                RoutesScreen(onRouteTap = { id -> navController.navigate("route_detail/$id") })
            }
            composable(
                route = ROUTE_DETAIL_TEMPLATE,
                arguments = listOf(navArgument("routeId") { type = NavType.StringType })
            ) { entry ->
                RouteDetailScreen(
                    routeId = entry.arguments?.getString("routeId").orEmpty(),
                    onBack = { navController.popBackStack() }
                )
            }

            composable(Tab.Bikes.route) {
                BikesScreen(onBikeTap = { id -> navController.navigate("bike_detail/$id") })
            }
            composable(
                route = BIKE_DETAIL_TEMPLATE,
                arguments = listOf(navArgument("bikeId") { type = NavType.StringType })
            ) { entry ->
                BikeDetailScreen(
                    bikeId = entry.arguments?.getString("bikeId").orEmpty(),
                    onBack = { navController.popBackStack() }
                )
            }

            composable(Tab.More.route) {
                MoreScreen(onNavigate = { dest -> navController.navigate(dest) })
            }
            composable("community") { CommunityFeedScreen(onBack = { navController.popBackStack() }) }
            composable("events") { EventsScreen(onBack = { navController.popBackStack() }) }
            composable("programs") { ProgramsScreen(onBack = { navController.popBackStack() }) }
            composable("gallery") { GalleryScreen(onBack = { navController.popBackStack() }) }
            composable("guides") { TourGuidesScreen(onBack = { navController.popBackStack() }) }
            composable("volunteer") { VolunteerScreen(onBack = { navController.popBackStack() }) }
            composable("donate") { DonateScreen(onBack = { navController.popBackStack() }) }
            composable("swiss") { SwissArmyKnifeScreen(onBack = { navController.popBackStack() }) }

            composable("expeditions") {
                ExpeditionListScreen(
                    onBack = { navController.popBackStack() },
                    onOpen = { id -> navController.navigate("expedition/$id") },
                    onNew = { navController.navigate("expedition_new") }
                )
            }
            composable("expedition_new") {
                ExpeditionNewScreen(
                    onBack = { navController.popBackStack() },
                    onCreated = { id ->
                        navController.popBackStack()
                        navController.navigate("expedition/$id")
                    }
                )
            }
            composable(
                route = "expedition/{journalId}",
                arguments = listOf(navArgument("journalId") { type = NavType.StringType })
            ) { entry ->
                val id = entry.arguments?.getString("journalId").orEmpty()
                ExpeditionDetailScreen(
                    journalId = id,
                    onBack = { navController.popBackStack() },
                    onAddEntry = { journalId -> navController.navigate("expedition_capture/$journalId") }
                )
            }
            composable(
                route = "expedition_capture/{journalId}",
                arguments = listOf(navArgument("journalId") { type = NavType.StringType })
            ) { entry ->
                ExpeditionCaptureScreen(
                    journalId = entry.arguments?.getString("journalId").orEmpty(),
                    onBack = { navController.popBackStack() }
                )
            }
        }
    }
}

private fun isInTabFamily(tab: Tab, currentRoute: String?): Boolean {
    if (currentRoute == null) return false
    return when (tab) {
        Tab.Routes -> currentRoute.startsWith("route_detail/")
        Tab.Bikes -> currentRoute.startsWith("bike_detail/")
        Tab.More -> currentRoute in setOf(
            "community", "events", "programs", "gallery", "guides", "volunteer", "donate",
            "expeditions", "expedition_new", "swiss"
        ) || currentRoute.startsWith("expedition/") || currentRoute.startsWith("expedition_capture/")
        else -> false
    }
}
