import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/reset_password_controller.dart';

class ResetPasswordView extends GetView<ResetPasswordController> {
  const ResetPasswordView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller.emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return ElevatedButton(
                onPressed: controller.resetPassword,
                child: const Text("Reset Password"),
              );
            }),
            const SizedBox(height: 16),
            Obx(() => Text(
                  controller.resetError.value,
                  style: const TextStyle(color: Colors.red),
                )),
            Obx(() => Text(
                  controller.resetSuccess.value,
                  style: const TextStyle(color: Colors.green),
                )),
          ],
        ),
      ),
    );
  }
}
