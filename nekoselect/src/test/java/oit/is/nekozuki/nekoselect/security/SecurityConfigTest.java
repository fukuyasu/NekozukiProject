package oit.is.nekozuki.nekoselect.security;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class SecurityConfigTest {

  @Autowired
  private MockMvc mockMvc;

  @ParameterizedTest
  @ValueSource(ints = { 1, 10 })
  void preparedParticipantCanLoginAndReturnToRequestedPage(int participantNumber) throws Exception {
    MvcResult loginPage = mockMvc.perform(get("/"))
        .andExpect(status().is3xxRedirection())
        .andExpect(redirectedUrl("/login"))
        .andReturn();

    MockHttpSession unauthenticatedSession = (MockHttpSession) loginPage.getRequest().getSession(false);
    MvcResult login = mockMvc.perform(post("/login")
        .param("username", "user" + participantNumber)
        .param("password", "p@ss")
        .with(csrf())
        .session(unauthenticatedSession))
        .andExpect(status().is3xxRedirection())
        .andExpect(redirectedUrl("/"))
        .andReturn();

    MockHttpSession authenticatedSession = (MockHttpSession) login.getRequest().getSession(false);
    mockMvc.perform(get("/").session(authenticatedSession))
        .andExpect(status().isOk());
  }

  @ParameterizedTest
  @ValueSource(ints = { 1, 10 })
  void incorrectPasswordDoesNotAuthenticateParticipant(int participantNumber) throws Exception {
    mockMvc.perform(post("/login")
        .param("username", "user" + participantNumber)
        .param("password", "incorrect")
        .with(csrf()))
        .andExpect(status().is3xxRedirection())
        .andExpect(redirectedUrl("/login?error"));

    mockMvc.perform(get("/"))
        .andExpect(status().is3xxRedirection())
        .andExpect(redirectedUrl("/login"));
  }
}
