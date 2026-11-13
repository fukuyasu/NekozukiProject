package oit.is.inudaisuki.springboot_samples.model;

public class ChamberUser {
  String userName;
  String chamberName;
  int age;
  double height;

  public int getAge() {
    return age;
  }

  public void setAge(int age) {
    this.age = age;
  }

  public double getHeight() {
    return height;
  }

  public void setHeight(double height) {
    this.height = height;
  }

  public String getChamberName() {
    return chamberName;
  }

  public void setChamberName(String chamberName) {
    this.chamberName = chamberName;
  }

  public String getUserName() {
    return userName;
  }

  public void setUserName(String userName) {
    this.userName = userName;
  }

}
