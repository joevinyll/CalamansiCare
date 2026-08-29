package com.example.calamansi_care

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val locationChannel = "calamansi_care/location"
    private val locationRequestCode = 4172
    private var pendingLocationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCurrentLocation") {
                    handleLocationRequest(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun handleLocationRequest(result: MethodChannel.Result) {
        if (!isOnline()) {
            result.error("offline", "Phone appears offline.", null)
            return
        }
        if (!isLocationServiceEnabled()) {
            result.error("service_disabled", "Location service is turned off.", null)
            return
        }
        if (!hasLocationPermission()) {
            pendingLocationResult = result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ),
                    locationRequestCode
                )
            } else {
                result.error("permission_denied", "Location permission was not allowed.", null)
            }
            return
        }
        sendLastKnownLocation(result)
    }

    private fun sendLastKnownLocation(result: MethodChannel.Result) {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        val location = providers
            .filter { provider -> manager.isProviderEnabled(provider) }
            .mapNotNull { provider ->
                try {
                    manager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                } catch (_: IllegalArgumentException) {
                    null
                }
            }
            .maxByOrNull { it.time }

        if (location == null) {
            result.error("location_unavailable", "No phone location is available.", null)
            return
        }

        result.success(
            mapOf(
                "address" to resolveAddress(location),
                "coordinates" to String.format(
                    Locale.US,
                    "%.5f, %.5f",
                    location.latitude,
                    location.longitude
                )
            )
        )
    }

    private fun resolveAddress(location: Location): String {
        return try {
            @Suppress("DEPRECATION")
            val address = Geocoder(this, Locale.getDefault())
                .getFromLocation(location.latitude, location.longitude, 1)
                ?.firstOrNull()
            listOfNotNull(
                address?.locality,
                address?.subAdminArea,
                address?.adminArea
            ).distinct().joinToString(", ")
        } catch (_: Exception) {
            ""
        }
    }

    private fun hasLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            true
        } else {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun isLocationServiceEnabled(): Boolean {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun isOnline(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != locationRequestCode) return
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            sendLastKnownLocation(result)
        } else {
            result.error("permission_denied", "Location permission was not allowed.", null)
        }
    }
}
