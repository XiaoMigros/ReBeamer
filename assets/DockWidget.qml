import QtQuick 2.0
import QtQuick.Controls 2.2 as SW
import QtQuick.Controls 1.5
import QtQuick.Layouts 1.3

Item {
	id: dockItem;
	anchors.fill: parent;
	
	SW.Switch {
		id: dockEnabled;
		x: 10;
		y: 10;
		checked: true;
		text: "Enabled";
		onClicked: {active = checked}
		Component.onCompleted: {active = checked}
	}
	
	RowLayout {
		anchors.margins: 10;
		anchors.top: dockEnabled.bottom;
		Button {
			id: helpButton;
			text: "Help";
			onClicked: {
				Qt.openUrlExternally("https://github.com/xiaomigros/beam-over-rests#readme")
			}//onClicked
		}//Button
		
		Button {
			id: quitButton;
			text: "Quit";
			onClicked: {
				dockEnabled.checked = false;
				smartQuit()
			}//onClicked
		}//Button
	}//RowLayout
}//Item