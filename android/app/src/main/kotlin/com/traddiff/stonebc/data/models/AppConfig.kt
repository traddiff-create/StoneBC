package com.traddiff.stonebc.data.models

import kotlinx.serialization.Serializable

@Serializable
data class AppConfig(
    val coalitionName: String,
    val shortName: String,
    val tagline: String,
    val websiteURL: String,
    val email: String,
    val phone: String? = null,
    val instagramHandle: String? = null,
    val location: Location? = null,
    val colors: Colors = Colors(),
    val features: Features = Features(),
    val dataURLs: DataURLs = DataURLs(),
    val apiKeys: ApiKeys? = null
) {
    @Serializable
    data class Location(
        val name: String,
        val address: String,
        val city: String,
        val state: String,
        val zip: String
    )

    @Serializable
    data class Colors(
        val brandBlue: String = "#2563eb",
        val brandGreen: String = "#059669",
        val brandAmber: String = "#f59e0b"
    )

    @Serializable
    data class Features(
        val enableMarketplace: Boolean = true,
        val enableCommunityFeed: Boolean = true,
        val enableRoutes: Boolean = true,
        val enableEvents: Boolean = true,
        val enableGallery: Boolean = true,
        val enableRadio: Boolean = false,
        val enableWeather: Boolean = true
    )

    @Serializable
    data class DataURLs(
        val wordpressBase: String = "",
        val bikes: String = "",
        val events: String = "",
        val posts: String = ""
    )

    @Serializable
    data class ApiKeys(
        val trailforksAppId: String? = null,
        val trailforksAppSecret: String? = null,
        val stravaClientId: String? = null,
        val stravaClientSecret: String? = null,
        val openWeatherApiKey: String? = null
    )

    companion object {
        val Default = AppConfig(
            coalitionName = "Stone Bicycle Coalition",
            shortName = "SBC",
            tagline = "Building Community Through Cycling",
            websiteURL = "https://stonebicyclecoalition.com",
            email = "info@stonebicyclecoalition.com"
        )
    }
}
