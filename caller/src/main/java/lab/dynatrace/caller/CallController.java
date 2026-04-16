package lab.dynatrace.caller;

import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
import java.util.List;

@RestController
public class CallController {

    @Value("${target.url}")
    private String targetUrl;

    @GetMapping("/call")
    public String call() {
        RestTemplate restTemplate = buildRestTemplate();

        HttpHeaders headers = new HttpHeaders();
        headers.set("x-probe-ts", Instant.now().toString());

        HttpEntity<Void> entity = new HttpEntity<>(headers);

        ResponseEntity<String> response = restTemplate.exchange(
            targetUrl,
            HttpMethod.GET,
            entity,
            String.class
        );

        return "status=" + response.getStatusCode();
    }

    private RestTemplate buildRestTemplate() {
        // Apache HttpClient 5 come transport:
        // - OneAgent lo strumenta e inietta traceparent/x-dynatrace prima dell'invio TCP
        // - il wire log (logging.level.org.apache.hc.client5.http.wire=DEBUG) mostra i byte raw
        //   compreso quello che OneAgent ha aggiunto
        var factory = new HttpComponentsClientHttpRequestFactory(HttpClients.createDefault());
        var rt = new RestTemplate(factory);

        // Interceptor applicativo: mostra gli header CHE NOI aggiungiamo.
        // NOTA: OneAgent inietta DOPO questo punto, quindi qui non si vedranno
        //       traceparent/x-dynatrace. Per quelli: guarda il wire log o il receiver.
        rt.setInterceptors(List.of(appLevelLogger()));
        return rt;
    }

    private ClientHttpRequestInterceptor appLevelLogger() {
        return (request, body, execution) -> {
            System.out.println("\n>>> APP-LEVEL HEADERS (prima di OneAgent) <<<");
            System.out.println("    URI    : " + request.getURI());
            request.getHeaders().forEach((name, values) ->
                values.forEach(v -> System.out.println("    " + name + ": " + v))
            );
            System.out.println(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
            return execution.execute(request, body);
        };
    }
}
