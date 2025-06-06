package eu.notesia

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.navigation.NavHostController

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InputScreen(navController: NavHostController) {
    var itemName by remember { mutableStateOf("") }
    var timerValue by remember { mutableStateOf("00:00:00") }
    var showNumpad by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add New Timer") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                modifier = Modifier.fillMaxWidth()
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {
                navController.previousBackStackEntry?.savedStateHandle?.set("newItem", itemName)
                navController.previousBackStackEntry?.savedStateHandle?.set("timerValue", timerValue)
                navController.popBackStack()
            }) {
                Icon(Icons.Default.Check, contentDescription = "Save")
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(if (showNumpad) Color.Gray.copy(alpha = 0.5f) else Color.Transparent)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp)
            ) {
                TextField(
                    value = itemName,
                    onValueChange = { itemName = it },
                    label = { Text("Timer Name") },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    TextField(
                        value = timerValue,
                        onValueChange = { timerValue = it },
                        label = { Text("Timer Value (HH:MM:SS)") },
                        keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Text),
                        modifier = Modifier.weight(1f),
                        enabled = false
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(onClick = { showNumpad = true }) {
                        Text("+")
                    }
                }
            }

            if (showNumpad) {
                Numpad(
                    onValueChange = { newValue ->
                        timerValue = newValue
                    },
                    onClose = { showNumpad = false }
                )
            }
        }
    }
}

@Composable
fun Numpad(onValueChange: (String) -> Unit, onClose: () -> Unit) {
    var inputValue by remember { mutableStateOf("00:00:00") }

    Dialog(onDismissRequest = onClose) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    IconButton(onClick = onClose) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Close")
                    }
                }
                TextField(
                    value = inputValue,
                    onValueChange = { inputValue = it },
                    label = { Text("Enter Time (HH:MM:SS)") },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = false
                )
                Spacer(modifier = Modifier.height(16.dp))
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    val numpadButtons = listOf(
                        listOf("1", "2", "3"),
                        listOf("4", "5", "6"),
                        listOf("7", "8", "9"),
                        listOf("0")
                    )

                    numpadButtons.forEach { row ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            row.forEach { button ->
                                Button(onClick = {
                                    inputValue = updateTime(inputValue, button)
                                }) {
                                    Text(button)
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = {
                        onValueChange(inputValue)
                        onClose()
                    }) {
                        Text("OK")
                    }
                }
            }
        }
    }
}

fun updateTime(currentTime: String, newDigit: String): String {
    val parts = currentTime.split(":")
    val hours = parts[0].toInt()
    val minutes = parts[1].toInt()
    val seconds = parts[2].toInt()

    val newSeconds = seconds % 10 * 10 + newDigit.toInt()
    val newMinutes = if (newSeconds >= 60) minutes + 1 else minutes
    val newHours = if (newMinutes >= 60) hours + 1 else hours

    return String.format("%02d:%02d:%02d", newHours % 24, newMinutes % 60, newSeconds % 60)
}