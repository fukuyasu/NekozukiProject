package oit.is.inudaisuki.springboot_samples.model;

public class Chamber {
  int id;
  String userName;
  String chamberName;

  // Thymeleafでフィールドを扱うためにはgetter/setterが必ず必要
  // vscodeのソースコード右クリック->ソースアクションでsetter/getterを簡単に追加できる
  public String getUserName() {
    return userName;
  }

  public void setUserName(String userName) {
    this.userName = userName;
  }

  public String getChamberName() {
    return chamberName;
  }

  public void setChamberName(String chamberName) {
    this.chamberName = chamberName;
  }

  public int getId() {
    return id;
  }

  public void setId(int id) {
    this.id = id;
  }

}
