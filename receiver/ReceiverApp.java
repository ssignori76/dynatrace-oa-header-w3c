import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;

/**
 * Echo server minimale: stampa tutti gli header ricevuti e risponde 200.
 * Nessuna dipendenza esterna. Avvio: java ReceiverApp.java [porta]
 * Default porta: 9090
 */
public class ReceiverApp {

    public static void main(String[] args) throws IOException {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 9090;

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/", ReceiverApp::handle);
        server.start();

        System.out.println("Receiver in ascolto su porta " + port);
        System.out.println("Endpoint: http://0.0.0.0:" + port + "/headers\n");
    }

    static void handle(HttpExchange exchange) throws IOException {
        System.out.println("\n=== RICHIESTA RICEVUTA ===");
        System.out.println("Metodo : " + exchange.getRequestMethod());
        System.out.println("URI    : " + exchange.getRequestURI());
        System.out.println("Da     : " + exchange.getRemoteAddress());
        System.out.println("--- Header ---");

        exchange.getRequestHeaders().forEach((name, values) ->
            values.forEach(value -> System.out.println("  " + name + ": " + value))
        );

        System.out.println("==========================\n");

        byte[] response = "OK".getBytes();
        exchange.sendResponseHeaders(200, response.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(response);
        }
    }
}
