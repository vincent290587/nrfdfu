import 'package:dart_dfu/utils.dart';

import 'package:bluez/bluez.dart';

class MyAgent extends BlueZAgent {
  @override
  Future<BlueZAgentPinCodeResponse> requestPinCode(BlueZDevice device) async {
    return BlueZAgentPinCodeResponse.success('1234');
  }

  @override
  Future<BlueZAgentResponse> displayPinCode(
      BlueZDevice device, String pinCode) async {
    print('PinCode $pinCode');
    return BlueZAgentResponse.success();
  }

  @override
  Future<BlueZAgentPasskeyResponse> requestPasskey(BlueZDevice device) async {
    return BlueZAgentPasskeyResponse.success(1234);
  }

  @override
  Future<BlueZAgentResponse> displayPasskey(
      BlueZDevice device, int passkey, int entered) async {
    print('Passkey $passkey');
    return BlueZAgentResponse.success();
  }

  @override
  Future<BlueZAgentResponse> requestConfirmation(
      BlueZDevice device, int passkey) async {
    print('Confirmed with passkey $passkey');
    return BlueZAgentResponse.success();
  }
}

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

  // Register agent to handle pairing requests.
  var agent = MyAgent();
  await client.registerAgent(agent);

  // Request that our agent is used.
  await client.requestDefaultAgent();

  bool wasFound = false;
  debugPrint('Looking for devices on ${adapter.name}...');
  for (var device in client.devices) {
    print('  ${device.address} ${device.name}');
    if (device.name == devName) {
      await start_dfu(device);
      wasFound = true;
      break;
    }
  }

  if (!wasFound) {

    client.deviceAdded.listen((device) {
      debugPrint('Scanned: ${device.name} @ ${device.address} ' );
    });

    debugPrint('Device not known, scanning...');

    await adapter.startDiscovery();
    await Future.delayed(Duration(seconds: 7));
    await adapter.stopDiscovery();

    for (var device in client.devices) {
      print('  ${device.address} ${device.name}');
      if (device.name == devName) {
        wasFound = true;
        await start_dfu(device);
        break;
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
