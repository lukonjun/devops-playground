package de.lukonjun.helloworld.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.net.UnknownHostException;

@RestController
public class GreetingsController {

    @GetMapping("/greetings")
    public String greetings() {
        return "Hello World";
    }

    @GetMapping("/host")
    public String host() throws UnknownHostException {
        return InetAddress.getLocalHost().toString();
    }

}