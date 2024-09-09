import 'package:dart_dfu/utils.dart';
import 'package:nrfdfu/nrfdfu.dart' as nrfdfu;

import 'package:bluez/bluez.dart';

void start_dfu(BlueZDevice device) async {

  await device.connect();

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

  // TODO
}

void main(List<String> arguments) async {

  var client = BlueZClient();
  await client.connect();

  if (client.adapters.isEmpty) {
    debugPrint('No Bluetooth adapters found');
    await client.close();
    return;
  }

  var adapter = client.adapters[0];
  debugPrint('Bluetooth adapter ${adapter.name}');

  debugPrint('Searching for devices on ${adapter.name}...');
  for (var device in client.devices) {
    print('  ${device.address} ${device.name}');
  }

  client.deviceAdded.listen((device) {
    debugPrint('Scanned: ${device.name} @ ${device.address} ' );
    if (device.name == arguments[1]) {
      start_dfu(device);
      adapter.stopDiscovery();
    }
  });

  await adapter.startDiscovery();

  await Future.delayed(Duration(seconds: 15));

  await adapter.stopDiscovery();

  await client.close();
}
