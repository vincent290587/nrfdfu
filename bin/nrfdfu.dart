import 'package:dart_dfu/utils.dart';

import 'package:bluez/bluez.dart';

Future<void> start_dfu(BlueZDevice device) async {

  print('Connecting to device...');
  await device.connect();

  // // Get GATT services
  // final services = await device.getServices();
  //
  // // For this example, just pick the first characteristic
  // final characteristics = await services.first.getCharacteristics();

  for (var service in device.gattServices) {

    print('  Service ${service.uuid}');
    for (var characteristic in service.characteristics) {
      String characteristicValue;
      try {
        characteristicValue = '${await characteristic.readValue()}';
      } on BlueZNotPermittedException {
        characteristicValue = '<write only>';
      } on BlueZException catch (e) {
        characteristicValue = '<${e.message}>';
      } catch (e) {
        characteristicValue = '<$e>';
      }
      print(
          '    Characteristic ${characteristic.uuid} = $characteristicValue');
      for (var descriptor in characteristic.descriptors) {
        String descriptorValue;
        try {
          descriptorValue = '${await descriptor.readValue()}';
        } on BlueZNotPermittedException {
          descriptorValue = '<write only>';
        } on BlueZException catch (e) {
          descriptorValue = '<${e.message}>';
        } catch (e) {
          descriptorValue = '<$e>';
        }
        print('      Descriptor ${descriptor.uuid} = $descriptorValue');
      }
    }
  }


  // Disconnect from the device
  await device.disconnect();
  print('Disconnected from device.');

}

Future<void> main_fct(String devName) async {

  var client = BlueZClient();
  await client.connect();

  if (client.adapters.isEmpty) {
    debugPrint('No Bluetooth adapters found');
    await client.close();
    return;
  }

  var adapter = client.adapters[0];
  debugPrint('Bluetooth adapter ${adapter.name}');

  bool wasFound = false;
  debugPrint('Looking for devices on ${adapter.name}...');
  for (var device in client.devices) {
    print('  ${device.address} ${device.name}');
    if (device.name == devName) {
      await start_dfu(device);
      wasFound = true;
    }
  }

  if (!wasFound) {

    client.deviceAdded.listen((device) {
      debugPrint('Scanned: ${device.name} @ ${device.address} ' );
    });

    debugPrint('Device no known, scanning...');

    await adapter.startDiscovery();
    await Future.delayed(Duration(seconds: 7));
    await adapter.stopDiscovery();

    for (var device in client.devices) {
      print('  ${device.address} ${device.name}');
      if (device.name == devName) {
        wasFound = true;
        await start_dfu(device);
      }
    }

    if (!wasFound) {
      debugPrint('Device not found, closing');
    }
  }

  await client.close();
}

void main(List<String> arguments) {

  if (arguments.isEmpty) {
    debugPrint('Please specify device name');
    return;
  }

  main_fct(arguments[0]);
}
