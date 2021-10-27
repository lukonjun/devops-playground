package de.lukonjun.helloworld;

import de.lukonjun.helloworld.controller.GreetingsController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;


@SpringBootTest
class HelloWorldApplicationTests {

	@Autowired
	GreetingsController greetingsController;

	@Test
	void contextLoads() {
		assertEquals(greetingsController.greetings(),"Hello World");
	}

	@Test
	void anotherTest() {
		assertTrue(greetingsController.greetings().contains("Hello"));
	}

	@Test
	void validateNotNull(){
		assertNotNull(greetingsController.greetings());
	}

}
