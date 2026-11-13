package oit.is.inudaisuki.springboot_samples.controller;

import java.security.Principal;
import java.util.ArrayList;

import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

import oit.is.inudaisuki.springboot_samples.model.Chamber;
import oit.is.inudaisuki.springboot_samples.model.ChamberUser;
import oit.is.inudaisuki.springboot_samples.model.UserInfo;
import oit.is.inudaisuki.springboot_samples.service.ChamberService;

/**
 * /sample3へのリクエストを扱うクラス authenticateの設定をしていれば， /sample3へのアクセスはすべて認証が必要になる
 */
@Controller
@RequestMapping("/sample4")
public class Sample41Controller {

  private final ChamberService chamberService;

  public Sample41Controller(ChamberService chamberService) {
    this.chamberService = chamberService;
  }

  @GetMapping("step1")
  public String sample41() {
    return "sample41.html";
  }

  @GetMapping("step3")
  public String sample43() {
    return "sample43.html";
  }

  @GetMapping("step5")
  public String sample45() {
    return "sample45.html";
  }

  @GetMapping("step6")
  public String sample46() {
    return "sample46.html";
  }

  /**
   * 指定したidをPATHパラメータで受け取り，そのidに対応するデータを取得して返す
   *
   * @param id
   * @param model
   * @return
   */
  @GetMapping("step2/{id}")
  public String sample42(@PathVariable Integer id, ModelMap model) {
    Chamber chamber2 = chamberService.findChamberById(id);
    model.addAttribute("chamber2", chamber2);

    return "sample41.html";
  }

  /**
   *
   * @param model Thymeleafにわたすデータを保持するオブジェクト
   * @param prin  ログインユーザ情報が保持されるオブジェクト
   * @return
   *
   *         DB登録とトランザクション処理はChamberServiceに任せる。
   *         ControllerはHTTPリクエストを受け取り、画面へ渡す値を準備する役割に絞る。
   */
  @PostMapping("step3")
  public String sample43(@RequestParam String chamberName, ModelMap model, Principal prin) {
    String loginUser = prin.getName(); // ログインユーザ情報
    Chamber chamber3 = new Chamber();
    chamber3.setChamberName(chamberName);
    chamber3.setUserName(loginUser);
    chamberService.addChamber(chamber3);
    model.addAttribute("chamber3", chamber3);
    // System.out.println("ID:" + chamber3.getId());
    return "sample43.html";
  }

  @PostMapping("step5")
  public String sample45(@RequestParam String chamberName, ModelMap model) {
    ArrayList<Chamber> chambers5 = chamberService.findChambersByName(chamberName);
    model.addAttribute("chambers5", chambers5);
    return "sample45.html";
  }

  @GetMapping("step7")
  public String sample47(ModelMap model) {
    ArrayList<ChamberUser> chamberUsers7 = chamberService.findChamberUsers();
    model.addAttribute("chamberUsers7", chamberUsers7);
    return "sample46.html";
  }

  @PostMapping("step8")
  public String sample48(@RequestParam Double height, @RequestParam Integer age, ModelMap model, Principal prin) {
    String loginUser = prin.getName(); // ログインユーザ情報
    UserInfo ui = new UserInfo();
    ui.setUserName(loginUser);
    ui.setAge(age);
    ui.setHeight(height);
    // insert後にすべての身長が登録されているユーザを取得する。
    // 登録済みユーザなどのエラーは握りつぶさず、Springの標準エラー画面で知らせる。
    ArrayList<ChamberUser> chamberUsers7 = chamberService.addUserInfoAndFindChamberUsers(ui);
    model.addAttribute("chamberUsers7", chamberUsers7);
    return "sample46.html";
  }

}
