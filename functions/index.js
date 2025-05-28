const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inicializa o SDK Admin do Firebase (apenas uma vez)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();
const FUNCTION_TIMEZONE = "America/Sao_Paulo"; // <<< AJUSTE PARA SEU TIMEZONE

/**
 * Cloud Function agendada para verificar contas prestes a vencer
 * e enviar notificações.
 * Roda todos os dias às 08:00 no timezone especificado.
 */
exports.dailyBillReminderScheduler = functions.pubsub
    .schedule("every day 08:00") // Para testar, pode usar "every 5 minutes"
    .timeZone(FUNCTION_TIMEZONE)
    .onRun(async (context) => {
      console.log(
          `Iniciando verificação de contas às ${new Date().toISOString()} ` +
      `no timezone ${FUNCTION_TIMEZONE}`,
      );

      const nowInFunctionTimezone = new Date(
          new Date().toLocaleString("en-US", {timeZone: FUNCTION_TIMEZONE}),
      );
      const startOfToday = new Date(
          nowInFunctionTimezone.getFullYear(),
          nowInFunctionTimezone.getMonth(),
          nowInFunctionTimezone.getDate(),
      );

      const limitDateForQuery = new Date(startOfToday);
      // Contas vencendo HOJE até HOJE + 4 dias (janela de 5 dias)
      limitDateForQuery.setDate(startOfToday.getDate() + 4);

      console.log(
          `Janela de consulta: de ${startOfToday.toISOString()} até ` +
      `${limitDateForQuery.toISOString()}`,
      );

      try {
        const accountsSnapshot = await db
            .collection("accounts") // <<< SUA COLEÇÃO DE CONTAS
            .where("isPaid", "==", false)
            .where("dueDate", ">=", admin.firestore.Timestamp.fromDate(startOfToday))
            .where(
                "dueDate", "<=", admin.firestore.Timestamp.fromDate(limitDateForQuery),
            )
            .get();

        if (accountsSnapshot.empty) {
          console.log(
              "Nenhuma conta encontrada na janela de vencimento e não paga.",
          );
          return null;
        }

        console.log(
            `Encontradas ${accountsSnapshot.size} contas para ` +
        "potencial notificação.",
        );

        const notificationPromises = [];

        for (const doc of accountsSnapshot.docs) {
          const accountData = doc.data();
          const accountId = doc.id;
          const userId = accountData.userId; // <<< SEU CAMPO userId NA CONTA
          const accountName = accountData.name || "Sua conta";
          const dueDateTimestamp = accountData.dueDate; // Já é um Timestamp
          const dueDate = dueDateTimestamp.toDate();

          if (!userId) {
            console.warn(
                `Conta ${accountId} (${accountName}) não possui userId. Pulando.`,
            );
            continue;
          }

          // <<< SUA COLEÇÃO DE USUÁRIOS (ex: "users")
          const userDoc = await db.collection("users").doc(userId).get();

          if (!userDoc.exists) {
            console.warn(
                `Usuário ${userId} (dono da conta ${accountId}) não encontrado. ` +
            "Pulando.",
            );
            continue;
          }

          const fcmToken = userDoc.data().fcmToken;

          if (!fcmToken) {
            console.warn(
                `Usuário ${userId} (dono da conta ${accountId}) não possui ` +
            "fcmToken. Pulando.",
            );
            continue;
          }

          const todayForDiff = new Date(startOfToday);
          todayForDiff.setHours(0, 0, 0, 0);
          const dueDateForDiff = new Date(dueDate);
          dueDateForDiff.setHours(0, 0, 0, 0);

          // Diferença em milissegundos
          const diffTime = dueDateForDiff.getTime() - todayForDiff.getTime();
          // Arredonda para o dia mais próximo
          const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

          let dayString = "hoje";
          if (diffDays === 0) {
            dayString = "hoje";
          } else if (diffDays === 1) {
            dayString = "amanhã";
          } else if (diffDays > 1) {
            dayString = `em ${diffDays} dias`;
          } else { // Venceu
            dayString = `venceu há ${Math.abs(diffDays)} dia(s)`;
          }

          const formattedDueDate = dueDate.toLocaleDateString("pt-BR", {
            day: "2-digit",
            month: "2-digit",
            year: "numeric",
            timeZone: FUNCTION_TIMEZONE,
          });

          const messagePayload = {
            notification: {
              title: "🗓️ Lembrete de Conta!",
              body: `Sua conta "${accountName}" vence ${dayString} ` +
                  `(${formattedDueDate}). Não se esqueça!`,
            },
            data: {
              accountId: accountId,
              billName: accountName,
              dueDate: dueDate.toISOString(),
              notificationType: "BILL_REMINDER_TRIGGER",
            },
            token: fcmToken,
            android: {
              priority: "high",
            // notification: { sound: "default" }
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
          };

          console.log(
              `Enviando notificação para usuário ${userId} sobre a conta ` +
          accountId,
          );
          notificationPromises.push(messaging.send(messagePayload));
        }

        await Promise.allSettled(notificationPromises).then((results) => {
          results.forEach((result, index) => {
            if (result.status === "fulfilled") {
              console.log(
                  `Notificação ${index + 1} enviada com sucesso: ${result.value}`,
              );
            } else {
              console.error(
                  `Falha ao enviar notificação ${index + 1}: ${result.reason}`,
              );
            }
          });
        });
        console.log("Processo de lembretes de contas concluído.");
        return null;
      } catch (error) {
        console.error(
            "Erro CRÍTICO ao processar lembretes de contas:", error,
        );
        return null;
      }
    });
