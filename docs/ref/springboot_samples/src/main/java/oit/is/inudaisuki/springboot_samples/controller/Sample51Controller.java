package oit.is.inudaisuki.springboot_samples.controller;

import java.util.ArrayList;

import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

import oit.is.inudaisuki.springboot_samples.model.Fruit;
import oit.is.inudaisuki.springboot_samples.service.AsyncShopService57;

/**
 * /sample5へのリクエストを扱うクラス authenticateの設定をしていれば， /sample5へのアクセスはすべて認証が必要になる
 */
@Controller
@RequestMapping("/sample5")
public class Sample51Controller {

  private final AsyncShopService57 fruitService;

  public Sample51Controller(AsyncShopService57 fruitService) {
    this.fruitService = fruitService;
  }

  @GetMapping("step1")
  public String sample51() {
    return "sample51.html";
  }

  @GetMapping("step2")
  public String sample52(ModelMap model) {
    ArrayList<Fruit> fruits2 = fruitService.syncShowFruitsList();
    model.addAttribute("fruits2", fruits2);
    return "sample51.html";
  }

  @GetMapping("step3")
  public String sample53(@RequestParam Integer id, ModelMap model) {
    // 削除対象のフルーツを取得
    Fruit fruit3 = fruitService.deleteFruit(id);
    model.addAttribute("fruit3", fruit3);
    fruitService.notifyFruitsUpdated();

    // 削除後のフルーツリストを取得
    ArrayList<Fruit> fruits2 = fruitService.syncShowFruitsList();
    model.addAttribute("fruits2", fruits2);
    return "sample51.html";
  }

  @GetMapping("step4")
  public String sample54(@RequestParam Integer id, ModelMap model) {
    // 編集対象のフルーツを取得
    Fruit fruit4 = fruitService.findFruitById(id);
    model.addAttribute("fruit4", fruit4);

    // フルーツリストを取得
    ArrayList<Fruit> fruits2 = fruitService.syncShowFruitsList();
    model.addAttribute("fruits2", fruits2);
    return "sample51.html";
  }

  /**
   * IDをクエリParamで，果物の名前と値段をフォームで受け取り，DBを更新する
   *
   * @param name
   * @param price
   * @param model
   * @return
   */
  @PostMapping("step5")
  public String sample55(@RequestParam Integer id, @RequestParam String name, @RequestParam Integer price,
      ModelMap model) {
    Fruit fruit = new Fruit(id, name, price);
    // update
    fruitService.updateFruit(fruit);
    fruitService.notifyFruitsUpdated();
    // フルーツリストを取得
    ArrayList<Fruit> fruits2 = fruitService.syncShowFruitsList();
    model.addAttribute("fruits2", fruits2);

    return "sample51.html";
  }

}
