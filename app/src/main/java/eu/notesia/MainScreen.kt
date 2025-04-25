package eu.notesia

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(navController: NavHostController) {
    var items by remember { mutableStateOf(listOf<String>()) }

    // Handle the result from the input screen
    val newItem = navController.currentBackStackEntry?.savedStateHandle?.get<String>("newItem")
    val timerValue = navController.currentBackStackEntry?.savedStateHandle?.get<String>("timerValue")
    if (newItem != null && timerValue != null) {
        items = items + "$newItem ($timerValue)"
        navController.currentBackStackEntry?.savedStateHandle?.remove<String>("newItem")
        navController.currentBackStackEntry?.savedStateHandle?.remove<String>("timerValue")
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Active Timers") },
                modifier = Modifier.fillMaxWidth()
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {
                navController.navigate("input")
            }) {
                Icon(Icons.Default.Add, contentDescription = "Add")
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp)
        ) {
            items(items) { item ->
                Text(text = item, modifier = Modifier.padding(8.dp))
            }
        }
    }
}
