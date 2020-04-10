import 'package:azap_app/classes/doctorPayload.dart';
import 'package:azap_app/classes/genericPayload.dart';
import 'package:azap_app/classes/locationPayload.dart';
import 'package:azap_app/classes/queuePayload.dart';
import 'package:azap_app/stores/doctor.dart';
import 'package:azap_app/stores/location.dart';
import 'package:azap_app/stores/queue.dart';
import 'package:azap_app/main.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:requests/requests.dart';

import '../main.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  var logger = Logger();

  factory HttpService() {
    return _instance;
  }

  HttpService._internal() {
  }

  // auto store cookie in storage
  Future<GenericPayload> login(int id, String secret) async {
    var genericPayload = GenericPayload();
    if(DotEnv().env['MODE_MOCK'] == 'false'){
      try {
        // TODO clear on disconnect
        String hostname = Requests.getHostname("${DotEnv().env['BASE_URL']}/api/v2/login");
        await Requests.clearStoredCookies(hostname);
        var r = await Requests.post(
            "${DotEnv().env['BASE_URL']}/api/v2/login",
            json: {
              "id": id,
              "secret": secret
            },
            timeoutSeconds: 30,
            bodyEncoding: RequestBodyEncoding.JSON);
        logger.i("http status from login ${r.statusCode}");
        // throw exception if not 200
        r.raiseForStatus();
        genericPayload = JsonMapper.deserialize<GenericPayload>(r.content());
        Requests.getStoredCookies(hostname).then((cookie) {
          logger.i('Session : ' + cookie.toString());
        });
        return genericPayload;
      } on Exception catch (e) {
        logger.e(e);
        genericPayload.status = 'error';
        return genericPayload;
      }
    } else {
      genericPayload.status = 'ok';
      return genericPayload;
    }
  }

  Future<QueuePayload> nextTicket() async {
    var queuePayload = QueuePayload();
    if(DotEnv().env['MODE_MOCK'] == 'false'){
      try {
        var r = await Requests.patch(
            "${DotEnv().env['BASE_URL']}/api/v2/doctors/${doctor.id}/next", timeoutSeconds: 30);
        logger.i("http status from next ticket ${r.statusCode}");
        // throw exception if not 200
        r.raiseForStatus();

        JsonMapper().useAdapter(JsonMapperAdapter(
            valueDecorators: {
              typeOf<List<Queue>>(): (value) => value.cast<Queue>()
            })
        );

        queuePayload = JsonMapper.deserialize<QueuePayload>(r.content());

        queue.tickets.clear();
        queue.replaceQueue(queuePayload.queueLines.elementAt(0));

        return queuePayload;
      } on Exception catch (e) {
        logger.e(e);
        queuePayload.status = 'error';
        return queuePayload;
      }
    } else {
      queuePayload.status = 'ok';
      return queuePayload;
    }
  }

  Future<DoctorPayload> createDoctor(Doctor newDoctor) async {
    var doctorPayload = DoctorPayload();
    if(DotEnv().env['MODE_MOCK'] == 'false'){
      try {
        var r = await Requests.post(
            "${DotEnv().env['BASE_URL']}/api/v2/doctor",
            json: {
              "locationId": newDoctor.locationId,
              "name": newDoctor.name,
              "phone": newDoctor.phone,
              "email": newDoctor.email,
            },
            bodyEncoding: RequestBodyEncoding.JSON,
            timeoutSeconds: 30);
        logger.i("http status from doctor ${r.statusCode}");
        // throw exception if not 200
        r.raiseForStatus();
        doctorPayload = JsonMapper.deserialize<DoctorPayload>(r.content());
        doctor.setDoctor(doctorPayload.payload);

        Queue newDoctorQueue = Queue();
        newDoctorQueue.doctorId = doctorPayload.payload.id;
        newDoctorQueue.name = doctorPayload.payload.name;
        queue.replaceQueue(newDoctorQueue);

        return doctorPayload;
      } on Exception catch (e) {
        logger.e(e);
        doctorPayload.status = 'error';
        return doctorPayload;
      }
    } else {
      newDoctor.id = 1;
      doctor.setDoctor(newDoctor);
      Queue docQueue = new Queue();
      docQueue.doctorId = newDoctor.id;
      docQueue.name = newDoctor.name;
      queue.replaceQueue(docQueue);
      doctorPayload.status = 'ok';
      return doctorPayload;
    }
  }

  Future<LocationPayload> createLocation(Location location) async {
    var locationPayload = LocationPayload();
    if(DotEnv().env['MODE_MOCK'] == 'false'){
      try {
        var r = await Requests.post(
            "${DotEnv().env['BASE_URL']}/api/v2/location",
            json: {
              "name": location.name,
              "address": location.address,
              "zipCode": location.zipCode,
              "city": location.city
            },
            bodyEncoding: RequestBodyEncoding.JSON);
        logger.i("http status from create location : ${r.statusCode}");
        // throw exception if not 200
        r.raiseForStatus();
        locationPayload = JsonMapper.deserialize<LocationPayload>(r.content());
        return locationPayload;
      } on Exception catch (e) {
        logger.e(e);
        locationPayload.status = 'error';
        return locationPayload;
      }
    } else {
      locationPayload.status = 'ok';
      return locationPayload;
    }
  }

  Future<DoctorPayload> linkDoctorToLocation(int doctorId, Location location) async {
    var linkDoctorLocationPayload = DoctorPayload();
    if(DotEnv().env['MODE_MOCK'] == 'false'){
      try {
        var r = await Requests.patch(
            "${DotEnv().env['BASE_URL']}/api/v2/doctors/$doctorId/location",
            json: {
              "locationId": location.id
            },
            bodyEncoding: RequestBodyEncoding.JSON);
        logger.i("http status from link doctor to location : ${r.statusCode}");
        // throw exception if not 200
        r.raiseForStatus();
        linkDoctorLocationPayload = JsonMapper.deserialize<DoctorPayload>(r.content());
        doctor.setDoctor(linkDoctorLocationPayload.payload);
        return linkDoctorLocationPayload;
      } on Exception catch (e) {
        logger.e(e);
        linkDoctorLocationPayload.status = 'error';
        return linkDoctorLocationPayload;
      }
    } else {
      doctor.locationId = location.id;
      linkDoctorLocationPayload.status = 'ok';
      return linkDoctorLocationPayload;
    }
  }

  // call if login return app status with doctors and tickets
  Future<QueuePayload> getStatus() async {
    var queuePayload = QueuePayload();
    if(DotEnv().env['MODE_MOCK'] == 'false'){
      String hostname = Requests.getHostname("${DotEnv().env['BASE_URL']}/api/v2/me");
      try {
        Requests.getStoredCookies(hostname).then((cookie) {
          logger.i('Session : ' + cookie.toString());
        });
        var r = await Requests.get("${DotEnv().env['BASE_URL']}/api/v2/me", timeoutSeconds: 30);
        logger.i("http status from get me : ${r.statusCode}");
        // throw exception if not 200
        r.raiseForStatus();

        JsonMapper().useAdapter(JsonMapperAdapter(
            valueDecorators: {
              typeOf<List<Queue>>(): (value) => value.cast<Queue>()
            })
        );

        queuePayload = JsonMapper.deserialize<QueuePayload>(r.content());

        if(queuePayload.queueLines.isNotEmpty){
          doctor.setDoctor(queuePayload.doctor);
          queue.tickets.clear();
          queue.replaceQueue(queuePayload.queueLines.elementAt(0));
        } else {
          logger.e("No doctors for session, clear cookies");
          // TODO check api. session with no doctor. Clear cookie
          Requests.clearStoredCookies(hostname);
          queuePayload.status = 'error';
        }

        return queuePayload;
      } on Exception catch (e) {
        logger.e(e);
        Requests.clearStoredCookies(hostname);
        queuePayload.status = 'error';
        return queuePayload;
      }
    } else {
      queuePayload.status = 'ok';
      return queuePayload;
    }
  }
}