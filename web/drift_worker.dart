// Code du « worker » web de la base de données (utilisé seulement par la
// version web). Compilé en web/drift_worker.js par tool/build_web.sh.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
