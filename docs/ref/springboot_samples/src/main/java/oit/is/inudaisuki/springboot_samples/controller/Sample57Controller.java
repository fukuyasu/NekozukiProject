package oit.is.inudaisuki.springboot_samples.controller;

import java.util.ArrayList;

import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import oit.is.inudaisuki.springboot_samples.model.Fruit;
import oit.is.inudaisuki.springboot_samples.service.AsyncShopService57;

/**
 * /sample5へのリクエストを扱うクラス authenticateの設定をしていれば， /sample5へのアクセスはすべて認証が必要になる
 * 他のクラスと同じRequestMappingも書ける．ただし，特定のメソッドへのGETリクエストのURLは一意じゃないとだめ．
 */
@Controller
@RequestMapping("/sample5")
public class Sample57Controller {

  private final AsyncShopService57 shop57;

  public Sample57Controller(AsyncShopService57 shop57) {
    this.shop57 = shop57;
  }

  /**
   * これまでと同様，フルーツのリストをDBから取得してthymeleafで返す処理
   *
   * @param model
   * @return
   */
  @GetMapping("step7")
  public String sample57(ModelMap model) {
    final ArrayList<Fruit> fruits7 = shop57.syncShowFruitsList();
    model.addAttribute("fruits7", fruits7);
    return "sample57.html";
  }

  @GetMapping("step8")
  public String sample58(@RequestParam Integer id, ModelMap model) {
    // 選択したフルーツを削除し，削除対象のフルーツをmodelに登録
    final Fruit fruit8 = this.shop57.deleteFruit(id);
    model.addAttribute("fruit8", fruit8);

    // 残りのフルーツリストを取得してmodelに登録
    final ArrayList<Fruit> fruits7 = shop57.syncShowFruitsList();
    model.addAttribute("fruits7", fruits7);

    // DB更新が完了してから、接続中の各ブラウザへ更新を伝える。
    shop57.notifyFruitsUpdated();

    return "sample57.html";
  }

  /**
   * JavaScriptからEventSourceとして呼び出されるGETリクエスト SseEmitterを返すことで，PUSH型の通信を実現する
   *
   * @return
   */
  @GetMapping("step9")
  public SseEmitter sample59() {
    return shop57.subscribeFruits();
  }

}
