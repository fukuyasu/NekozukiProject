package oit.is.inudaisuki.springboot_samples.controller;

import java.security.Principal;

import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

import oit.is.inudaisuki.springboot_samples.model.Room;

/**
 * /sample3へのリクエストを扱うクラス authenticateの設定をしていれば， /sample3へのアクセスはすべて認証が必要になる
 */
@Controller
@RequestMapping("/sample3")
public class Sample31Controller {

  private final Room room;

  /**
   * コンストラクタで必要な部品を受け取る。finalにできるため、生成後に別のRoomへ
   * 入れ替わってしまうことを防げる。
   *
   * @param room アプリケーションで共有するRoom
   */
  public Sample31Controller(Room room) {
    this.room = room;
  }

  @GetMapping("step1")
  public String sample31() {
    return "sample31.html";
  }

  @GetMapping("step3")
  public String sample33() {
    return "sample33.html";
  }

  @GetMapping("step7")
  public String sample37() {
    return "sample37.html";
  }

  /**
   *
   * @param model Thymeleafにわたすデータを保持するオブジェクト
   * @param prin  ログインユーザ情報が保持されるオブジェクト
   * @return
   */
  @GetMapping("step2")
  public String sample32(ModelMap model, Principal prin) {
    String loginUser = prin.getName(); // ログインユーザ情報
    model.addAttribute("login_user", loginUser);
    return "sample31.html";
  }

  @PostMapping("step6")
  public String sample36(@RequestParam Integer hiku1, @RequestParam Integer hiku2, ModelMap model) {
    int kekka = hiku1 - hiku2;
    model.addAttribute("hikukekka", kekka);
    return "sample33.html";
  }

  @GetMapping("step8")
  public String sample38(Principal prin, ModelMap model) {
    String loginUser = prin.getName();
    this.room.addUser(loginUser);
    model.addAttribute("room", this.room);

    return "sample37.html";
  }

  @GetMapping("step9")
  public String sample39(Principal prin, ModelMap model) {
    String loginUser = prin.getName();
    Room newRoom = new Room();
    newRoom.addUser(loginUser);
    model.addAttribute("new_room", newRoom);

    return "sample37.html";
  }

}
