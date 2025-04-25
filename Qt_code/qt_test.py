from PyQt6.QtWidgets import QApplication, QMainWindow, QPushButton, QVBoxLayout, QWidget, QLabel
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Simple PyQt6 App")
        
        # Create a central widget and set it as the central widget of the main window
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        
        # Create a layout for the central widget
        self.layout = QVBoxLayout()
        self.central_widget.setLayout(self.layout)
        
        # Create a label and add it to the layout
        self.label = QLabel("Hello, PyQt6!")
        self.layout.addWidget(self.label)
        
        # Create a button and add it to the layout
        self.button = QPushButton("Click Me!")
        self.button.clicked.connect(self.on_button_click)
        self.layout.addWidget(self.button)

    def on_button_click(self):
        self.label.setText("Button Clicked!")
        # Add Modbus communication widgets

        # Create a group box for Modbus settings
        self.modbus_group = QGroupBox("Modbus Settings")
        self.modbus_layout = QVBoxLayout()
        self.modbus_group.setLayout(self.modbus_layout)

        # Port selection
        self.port_label = QLabel("Port:")
        self.port_combo = QComboBox()
        self.port_combo.addItems(["COM1", "COM2", "COM3", "COM4"])  # Example ports
        self.port_layout = QHBoxLayout()
        self.port_layout.addWidget(self.port_label)
        self.port_layout.addWidget(self.port_combo)
        self.modbus_layout.addLayout(self.port_layout)

        # Baud rate selection
        self.bps_label = QLabel("Baud Rate:")
        self.bps_combo = QComboBox()
        self.bps_combo.addItems(["9600", "19200", "38400", "57600", "115200"])
        self.bps_layout = QHBoxLayout()
        self.bps_layout.addWidget(self.bps_label)
        self.bps_layout.addWidget(self.bps_combo)
        self.modbus_layout.addLayout(self.bps_layout)

        # Address selection
        self.address_label = QLabel("Address:")
        self.address_input = QLineEdit()
        self.address_input.setValidator(QIntValidator(0, 65535))  # Valid Modbus address range
        self.address_layout = QHBoxLayout()
        self.address_layout.addWidget(self.address_label)
        self.address_layout.addWidget(self.address_input)
        self.modbus_layout.addLayout(self.address_layout)

        # Add Modbus group to the main layout
        self.layout.addWidget(self.modbus_group)

        # Display area for Modbus data
        self.data_label = QLabel("Data:")
        self.data_display = QLabel("N/A")
        self.data_display.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.data_layout = QHBoxLayout()
        self.data_layout.addWidget(self.data_label)
        self.data_layout.addWidget(self.data_display)
        self.layout.addLayout(self.data_layout)

        # Indicator for BOOL variable
        self.bool_label = QLabel("BOOL Indicator:")
        self.bool_indicator = QLabel("OFF")
        self.bool_indicator.setStyleSheet("background-color: red; color: white; padding: 5px;")
        self.bool_layout = QHBoxLayout()
        self.bool_layout.addWidget(self.bool_label)
        self.bool_layout.addWidget(self.bool_indicator)
        self.layout.addLayout(self.bool_layout)

        # INT variable display
        self.int_label = QLabel("INT Value:")
        self.int_display = QLabel("0")
        self.int_layout = QHBoxLayout()
        self.int_layout.addWidget(self.int_label)
        self.int_layout.addWidget(self.int_display)
        self.layout.addLayout(self.int_layout)

        # Button to read Modbus data
        self.read_button = QPushButton("Read Modbus Data")
        self.read_button.clicked.connect(self.read_modbus_data)
        self.layout.addWidget(self.read_button)

        def read_modbus_data(self):
            try:
                # Initialize Modbus connection
                port = self.port_combo.currentText()
                baudrate = int(self.bps_combo.currentText())
                address = int(self.address_input.text())
                instrument = minimalmodbus.Instrument(port, address)
                instrument.serial.baudrate = baudrate
    
                # Read BOOL and INT values (example registers)
                bool_value = instrument.read_bit(0)  # Read coil at address 0
                int_value = instrument.read_register(1)  # Read holding register at address 1
    
                # Update UI
                self.bool_indicator.setText("ON" if bool_value else "OFF")
                self.bool_indicator.setStyleSheet("background-color: green; color: white; padding: 5px;" if bool_value else "background-color: red; color: white; padding: 5px;")
                self.int_display.setText(str(int_value))
            except Exception as e:
                self.data_display.setText(f"Error: {e}")
if __name__ == "__main__":
    import sys
from PyQt6.QtWidgets import QComboBox, QLineEdit, QHBoxLayout, QGroupBox
from PyQt6.QtGui import QIntValidator
from PyQt6.QtCore import Qt
import minimalmodbus
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())