"""
ESP32 Simulator - Python TCP Server
Simulasi perangkat ESP32 untuk menguji koneksi JSON dari Flutter App

Tanpa BLE - menggunakan TCP socket sebagai alternatif testing
"""

import asyncio
import json


SERVICE_PORT = 8888
SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"


class ESP32Simulator:
    """Simulasi perangkat ESP32 dengan TCP Server"""

    def __init__(self, host="0.0.0.0", port=SERVICE_PORT):
        self.host = host
        self.port = port
        self.server = None
        self.deret_data = {}

    def run(self):
        """Jalankan TCP server"""
        print(f"\n{'=' * 60}")
        print(f"  ESP32 Simulator - Lirik S3 (TCP Mode)")
        print(f"{'=' * 60}")
        print(f"Host: {self.host}:{self.port}")
        print(f"UUID: {SERVICE_UUID}")
        print(f"{'=' * 60}\n")

        asyncio.run(self._start_server())

    async def _start_server(self):
        """Mulai TCP server"""
        self.server = await asyncio.start_server(
            self._handle_client, self.host, self.port
        )

        addr = self.server.sockets[0].getsockname()
        print(f"Server started on {addr}")
        print(f"  - Buka Flutter App")
        print(f"  - Connect ke TCP server")
        print(f"\nTekan Ctrl+C untuk exit\n")

        async with self.server:
            await self.server.serve_forever()

    async def _handle_client(self, reader, writer):
        """Handle client connection"""
        addr = writer.get_extra_info("peername")
        print(f"\n[+] Client connected: {addr}")

        try:
            while True:
                data = await reader.read(1024)
                if not data:
                    break

                message = data.decode("utf-8")
                print(f"\n[RECEIVED {len(data)} bytes]: {message[:80]}...")

                self._process_message(message)

                # Send ACK
                writer.write(b"ACK\n")
                await writer.drain()

        except Exception as e:
            print(f"[ERROR] {e}")
        finally:
            print(f"\n[-] Client disconnected: {addr}")
            writer.close()

    def _process_message(self, message):
        """Proses pesan yang diterima"""
        if "[EOF]" in message:
            parts = message.split("[EOF]")
            for part in parts:
                if part.strip():
                    self._parse_json(part.strip())
        else:
            self._parse_json(message)

    def _parse_json(self, json_str):
        """Parse JSON"""
        try:
            data = json.loads(json_str)

            # Factory reset
            if "c" in data and data["c"] == "reset":
                print(f"\n[!] FACTORY RESET COMMAND")
                self.deret_data.clear()
                print(f"    Reset complete")
                return

            # Array (bulk) atau single
            if isinstance(data, list):
                print(f"\n[DATA] {len(data)} derets (bulk)")
                for deret in data:
                    self._store_deret(deret)
            else:
                print(f"\n[DATA] Deret d={data.get('d')}")
                self._store_deret(data)

        except json.JSONDecodeError:
            print(f"[WARNING] Not JSON: {json_str[:50]}")

    def _store_deret(self, deret):
        """Simpan data deret"""
        d_num = deret.get("d")
        name = deret.get("name", f"Deret {d_num}")
        words = deret.get("v", [])

        self.deret_data[d_num] = {"name": name, "words": words}

        print(f"\n  Deret {d_num}: {name}")
        print(f"     Kata: {len(words)}")
        for i, w in enumerate(words[:5]):
            print(f"        {i + 1}. [{w['t']}ms] {w['w']}")
        if len(words) > 5:
            print(f"        ... +{len(words) - 5} kata")


def main():
    print("\n========================================================")
    print("         ESP32 LIRIK SIMULATOR v1.0 (TCP)")
    print("         Python Server for Testing")
    print("========================================================\n")

    print("NOTE: bleak tidak support server/peripheral di Windows")
    print("      Gunakan TCP mode ini untuk testing\n")

    sim = ESP32Simulator()

    try:
        sim.run()
    except KeyboardInterrupt:
        print("\n\nShutting down...")
    except Exception as e:
        print(f"\n[ERROR] {e}")


if __name__ == "__main__":
    main()
