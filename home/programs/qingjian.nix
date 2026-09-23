{
  programs.qingjian = {
    enable = true;
    settings = {
      general = {
        learning_language = "en";
        input_log = true;
      };
      model.enabled = true;
      predict.enabled = false;
      update.check = false;
    };
  };
}
